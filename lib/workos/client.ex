# @oagen-ignore-file

defmodule WorkOS.Client do
  @moduledoc """
  HTTP client for the WorkOS API.

  ## Usage

      client = WorkOS.Client.new(api_key: "sk_...")

  The API key falls back to the `WORKOS_API_KEY` environment variable.

  To authenticate with workload identity federation instead of an API key,
  start a `WorkOS.WorkloadIdentity.Credentials` process and pass it in:

      client = WorkOS.Client.new(credentials: credentials)

  ## Options for `new/1`

    * `:api_key` — API key (required unless the env var is set or
      `:credentials` is given)
    * `:credentials` — the pid or registered name of a started
      `WorkOS.WorkloadIdentity.Credentials` process. Passing both `:api_key`
      and `:credentials` raises `WorkOS.ConfigurationError`. With
      `:credentials`, `WORKOS_API_KEY` is ignored and never sent.
    * `:client_id` — client ID used by authentication flows and URL builders
      (falls back to the `WORKOS_CLIENT_ID` environment variable)
    * `:base_url` — override the API base URL
    * `:jwt_issuer` — accepted `iss` claim (a string or a list of strings) for
      session access tokens verified by `WorkOS.Session.authenticate/1`; falls
      back to the comma-separated `WORKOS_ISSUER` environment variable. When
      unset, the issuer is not checked.
    * `:timeout` — receive timeout in milliseconds
    * `:max_retries` — maximum retry attempts for retryable failures
    * `:req_options` — extra `Req` options merged into every request
      (advanced; used by tests to inject `plug: {Req.Test, ...}`)
  """

  import Bitwise

  defstruct [
    :api_key,
    :credentials,
    :client_id,
    :base_url,
    :jwt_issuer,
    :timeout,
    :max_retries,
    :req_options
  ]

  @type t :: %__MODULE__{
          api_key: String.t() | nil,
          credentials: WorkOS.Credentials.t() | nil,
          client_id: String.t() | nil,
          base_url: String.t(),
          jwt_issuer: [String.t()] | nil,
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          req_options: keyword()
        }

  @api_key_env "WORKOS_API_KEY"
  @client_id_env "WORKOS_CLIENT_ID"
  @issuer_env "WORKOS_ISSUER"
  @default_base_url "https://api.workos.com"
  @default_timeout_ms 60_000
  @default_max_retries 3
  @retryable_status_codes [429, 500, 502, 503, 504]
  @initial_retry_delay_ms 1000
  @retry_multiplier 2
  @max_retry_delay_ms 30_000
  @retry_jitter 0.5
  @idempotency_header "idempotency-key"
  @request_id_header "x-request-id"

  # Req private keys. Private data survives Req's own retries and redirects,
  # so the one 401 recovery a logical request is allowed cannot be reset.
  @snapshot_key :workos_credential_snapshot
  @recovery_used_key :workos_credential_recovery_used

  @doc """
  Builds a new client. See the module documentation for options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    {api_key, credentials} = authentication(opts)

    %__MODULE__{
      api_key: api_key,
      credentials: credentials,
      client_id: opts[:client_id] || System.get_env(@client_id_env),
      base_url: String.trim_trailing(opts[:base_url] || @default_base_url, "/"),
      jwt_issuer: normalize_issuers(Keyword.get_lazy(opts, :jwt_issuer, &issuer_from_env/0)),
      timeout: opts[:timeout] || @default_timeout_ms,
      max_retries: opts[:max_retries] || @default_max_retries,
      req_options: opts[:req_options] || []
    }
  end

  @doc """
  Performs an HTTP request against the API.

  `params` is sent as query parameters for GET/DELETE/HEAD requests and as a
  JSON body otherwise. Per-request options:

    * `:headers` — extra headers, as a list of `{name, value}` tuples
    * `:idempotency_key` — explicit idempotency key header value
    * `:timeout` — per-request receive timeout in milliseconds
    * `:max_retries` — per-request retry ceiling, overriding the client's
    * `:base_url` — per-request base URL, overriding the client's
    * `:query` — extra query parameters for requests whose `params` is a body
  """
  @spec request(t(), atom(), String.t(), map(), keyword()) ::
          {:ok, term()} | {:error, WorkOS.Error.error()}
  def request(%__MODULE__{} = client, method, path, params \\ %{}, opts \\ []) do
    params = Map.new(params || %{}, fn {k, v} -> {to_string(k), v} end)
    query_method? = method in [:get, :delete, :head]

    query =
      if query_method?,
        do: params,
        else: Map.new(opts[:query] || %{}, fn {k, v} -> {to_string(k), v} end)

    query = encode_query_values(query)

    body = if query_method?, do: nil, else: params

    max_retries = opts[:max_retries] || client.max_retries
    timeout = opts[:timeout] || client.timeout
    credentials = credentials(client)

    req_options =
      [
        method: method,
        url: path,
        base_url: normalize_base_url(opts[:base_url]) || client.base_url,
        headers: build_headers(client, method, opts, max_retries),
        receive_timeout: timeout,
        retry: &retryable?/2,
        retry_delay: &retry_delay/1,
        max_retries: max_retries,
        decode_body: false
      ]
      |> put_query(query)
      |> put_body(body)

    req =
      req_options
      |> Req.new()
      |> Req.merge(client.req_options)
      |> Req.Request.append_request_steps(
        workos_credentials: &put_credentials(&1, credentials, timeout)
      )
      |> Req.Request.prepend_response_steps(
        workos_credential_recovery: &recover_credentials(&1, credentials)
      )

    req |> Req.request() |> handle_response()
  end

  # -- credentials ------------------------------------------------------------
  #
  # Every client authenticates through `WorkOS.Credentials`. A static API key
  # is the trivial implementation; a client built by hand with only a key
  # (as `WorkOS.PublicClient` does) gets it too.

  defp credentials(%__MODULE__{credentials: nil, api_key: api_key}),
    do: {WorkOS.Credentials.StaticKey, api_key}

  defp credentials(%__MODULE__{credentials: credentials}), do: credentials

  # Authentication precedence, in order: an explicit key together with
  # explicit credentials is an error; explicit credentials are used and
  # WORKOS_API_KEY is ignored; an explicit key is used; only when neither is
  # passed does WORKOS_API_KEY apply.
  defp authentication(opts) do
    case {opts[:api_key], opts[:credentials]} do
      {api_key, nil} ->
        {api_key!(api_key || System.get_env(@api_key_env)), nil}

      {nil, server} ->
        {nil, {WorkOS.WorkloadIdentity.Credentials, credentials_server!(server)}}

      {_api_key, _server} ->
        raise WorkOS.ConfigurationError,
          message:
            "Pass either `api_key:` or `credentials:` to WorkOS.Client.new/1, not both. " <>
              "A client authenticates with one or the other."
    end
  end

  defp api_key!(api_key) when is_binary(api_key) and api_key != "", do: api_key

  defp api_key!(_missing) do
    raise WorkOS.ConfigurationError,
      message: "Missing API key. Pass `api_key:` to WorkOS.Client.new/1 or set WORKOS_API_KEY."
  end

  # Anything `GenServer.call/3` can address.
  defp credentials_server!(server) when is_pid(server), do: server

  defp credentials_server!(server) when is_atom(server) and not is_boolean(server),
    do: server

  defp credentials_server!({:global, _name} = server), do: server
  defp credentials_server!({:via, module, _name} = server) when is_atom(module), do: server

  defp credentials_server!({name, node} = server) when is_atom(name) and is_atom(node),
    do: server

  defp credentials_server!(_other) do
    raise WorkOS.ConfigurationError,
      message:
        "`credentials:` must be the pid or registered name of a started " <>
          "WorkOS.WorkloadIdentity.Credentials process."
  end

  # Request step. Req runs request steps once per `Req.request/1`, but calls
  # the adapter for every HTTP attempt: the first one, each transport retry,
  # each redirect and the 401 recovery. Wrapping the adapter is therefore what
  # resolves the credentials before every attempt, so a retry never sends an
  # expired token. It runs last, after Req has chosen the adapter.
  defp put_credentials(%Req.Request{} = request, credentials, timeout) do
    adapter = request.adapter
    origin = origin(request.url)

    %{request | adapter: &send_attempt(&1, adapter, credentials, timeout, origin)}
  end

  defp send_attempt(request, adapter, credentials, timeout, origin) do
    if origin(request.url) == origin or request.options[:redirect_trusted] == true do
      send_with_credentials(request, adapter, credentials, timeout)
    else
      # A redirect to another origin. Req has already removed the
      # Authorization header; keep every credential header off the request.
      run_adapter(adapter, drop_credentials(request))
    end
  end

  defp send_with_credentials(request, adapter, credentials, timeout) do
    case WorkOS.Credentials.resolve(credentials, timeout) do
      {:ok, %WorkOS.CredentialSnapshot{} = snapshot} ->
        run_adapter(adapter, put_snapshot(request, snapshot))

      {:error, exception} ->
        # Terminal for the request: `retryable?/2` only retries Req's own
        # transport errors.
        {request, exception}
    end
  end

  # The snapshot's headers overwrite any the request already has. The snapshot
  # is kept so a 401 invalidates this credential, not whichever one is
  # current by then.
  defp put_snapshot(request, snapshot) do
    snapshot.headers
    |> Enum.reduce(request, fn {name, value}, request ->
      Req.Request.put_header(request, name, value)
    end)
    |> Req.Request.put_private(@snapshot_key, snapshot)
  end

  defp run_adapter(adapter, request) when is_function(adapter, 1), do: adapter.(request)

  defp run_adapter({module, function, args}, request),
    do: apply(module, function, [request | args])

  defp drop_credentials(request) do
    headers =
      case Req.Request.get_private(request, @snapshot_key) do
        %WorkOS.CredentialSnapshot{headers: headers} -> headers
        nil -> []
      end

    headers
    |> Enum.reduce(request, fn {name, _value}, request ->
      Req.Request.delete_header(request, name)
    end)
    |> Req.Request.put_private(@snapshot_key, nil)
  end

  defp origin(%URI{scheme: scheme, host: host, port: port}), do: {scheme, host, port}

  # Response step, ahead of Req's retry step. On a 401 for a recoverable
  # snapshot it invalidates that snapshot's generation and sends the same
  # request again (same body, same idempotency key), once per logical
  # request. The resend does not count against the retry limit and does not
  # wait for a backoff. Whatever comes back is handled as a normal response.
  defp recover_credentials({request, %Req.Response{status: 401} = response}, credentials) do
    snapshot = Req.Request.get_private(request, @snapshot_key)
    recovery_used? = Req.Request.get_private(request, @recovery_used_key, false)

    if match?(%WorkOS.CredentialSnapshot{recoverable: true}, snapshot) and not recovery_used? do
      request = Req.Request.put_private(request, @recovery_used_key, true)
      :ok = WorkOS.Credentials.invalidate(credentials, snapshot.generation)

      {request, response_or_exception} = Req.Request.run_request(%{request | halted: false})
      Req.Request.halt(request, response_or_exception)
    else
      {request, response}
    end
  end

  defp recover_credentials(request_and_response, _credentials), do: request_and_response

  defp handle_response({:ok, %Req.Response{status: status} = response})
       when status in 200..299,
       do: {:ok, decode_body(response)}

  defp handle_response({:ok, %Req.Response{} = response}), do: {:error, api_error(response)}

  # Errors from resolving credentials are already typed.
  defp handle_response({:error, %WorkOS.WorkloadIdentityError{} = error}), do: {:error, error}
  defp handle_response({:error, %WorkOS.TransportError{} = error}), do: {:error, error}

  defp handle_response({:error, %{__exception__: true} = exception}),
    do: {:error, %WorkOS.TransportError{message: Exception.message(exception), reason: exception}}

  @doc """
  Builds a fully-qualified URL for browser-redirect flows. No HTTP request
  is made. `params` become the query string; nil values are dropped.
  """
  @spec build_url(t(), String.t(), map()) :: String.t()
  def build_url(%__MODULE__{} = client, path, params \\ %{}) do
    query =
      params
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> {k, query_value(v)} end)
      |> URI.encode_query()

    case query do
      "" -> client.base_url <> path
      query -> client.base_url <> path <> "?" <> query
    end
  end

  # Req hands `:params` to URI.encode_query, which rejects list values outright
  # and mangles maps, so structured query values must be flattened to strings
  # before they get there — the same normalization `build_url/3` applies.
  # nil is left alone: `put_query` drops it rather than sending "".
  defp encode_query_values(query) do
    Map.new(query, fn
      {k, nil} -> {k, nil}
      {k, v} when is_list(v) or is_map(v) -> {k, query_value(v)}
      {k, v} -> {k, v}
    end)
  end

  defp query_value(value) when is_list(value), do: Enum.map_join(value, ",", &to_string/1)
  defp query_value(value) when is_map(value), do: JSON.encode!(value)
  defp query_value(value), do: to_string(value)

  @doc false
  @spec merge_defaults(map(), map()) :: map()
  def merge_defaults(params, defaults) do
    params
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> Map.merge(defaults)
  end

  @doc false
  @spec put_inferred(map(), String.t(), term()) :: map()
  def put_inferred(params, _key, nil), do: params
  def put_inferred(params, key, value), do: Map.put_new(params, key, value)

  # nil query values are omitted rather than sent as `key=`, matching build_url/3.
  defp put_query(req_options, query) do
    case Enum.reject(query, fn {_k, v} -> is_nil(v) end) do
      [] -> req_options
      pairs -> Keyword.put(req_options, :params, pairs)
    end
  end

  defp put_body(req_options, nil), do: req_options

  defp put_body(req_options, body) do
    req_options
    |> Keyword.put(:body, JSON.encode_to_iodata!(body))
    |> Keyword.update!(:headers, &[{"content-type", "application/json"} | &1])
  end

  defp issuer_from_env, do: System.get_env(@issuer_env)

  defp normalize_issuers(nil), do: nil

  defp normalize_issuers(issuers) do
    issuers
    |> List.wrap()
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> nil
      list -> list
    end
  end

  defp normalize_base_url(nil), do: nil
  defp normalize_base_url(url) when is_binary(url), do: String.trim_trailing(url, "/")

  defp build_headers(_client, method, opts, max_retries) do
    [{"user-agent", user_agent()}] ++
      idempotency_headers(method, opts, max_retries) ++ (opts[:headers] || [])
  end

  # A retried POST must be safe to replay, so when retries are enabled and the
  # caller supplied no key we mint one. `:idempotency` remains supported for
  # spec-driven opt-in (`injectIdempotencyKey`) even with retries disabled.
  defp idempotency_headers(method, opts, max_retries) do
    cond do
      is_binary(opts[:idempotency_key]) ->
        [{@idempotency_header, opts[:idempotency_key]}]

      method == :post and (opts[:idempotency] == true or max_retries > 0) ->
        [{@idempotency_header, generate_idempotency_key()}]

      true ->
        []
    end
  end

  @doc false
  @spec user_agent() :: String.t()
  def user_agent, do: "workos-elixir/#{Application.spec(:workos, :vsn)}"

  # The retry count and backoff are shared with the workload identity token
  # exchange, so there is one set of values.
  @doc false
  @spec default_max_retries() :: non_neg_integer()
  def default_max_retries, do: @default_max_retries

  defp retryable?(_request, %Req.Response{status: status}),
    do: status in @retryable_status_codes

  defp retryable?(_request, %Req.TransportError{}), do: true
  defp retryable?(_request, _other), do: false

  @doc false
  @spec retry_delay(non_neg_integer()) :: non_neg_integer()
  def retry_delay(attempt) do
    base =
      min(@initial_retry_delay_ms * :math.pow(@retry_multiplier, attempt), @max_retry_delay_ms)

    trunc(base + base * @retry_jitter * :rand.uniform())
  end

  defp decode_body(%Req.Response{body: body}) when body in [nil, ""], do: nil

  defp decode_body(%Req.Response{body: body}) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end

  defp decode_body(%Req.Response{body: body}), do: body

  defp api_error(%Req.Response{status: status} = response) do
    body = decode_body(response)

    %WorkOS.ApiError{
      message: error_message(body, status),
      status: status,
      kind: error_kind(status),
      request_id: response |> Req.Response.get_header(@request_id_header) |> List.first(),
      code: if(is_map(body), do: body["code"]),
      param: error_param(body),
      body: body
    }
  end

  # The offending field, when the API names one. WorkOS reports it either at the
  # top level (`field`/`param`) or per-entry under `errors`.
  defp error_param(%{"field" => field}) when is_binary(field), do: field
  defp error_param(%{"param" => param}) when is_binary(param), do: param

  defp error_param(%{"errors" => [first | _]}) when is_map(first),
    do: error_param(first)

  defp error_param(_body), do: nil

  defp error_message(%{"message" => message}, _status) when is_binary(message), do: message

  defp error_message(%{"error_description" => message}, _status) when is_binary(message),
    do: message

  defp error_message(%{"error" => message}, _status) when is_binary(message), do: message
  defp error_message(_body, status), do: "HTTP " <> Integer.to_string(status)

  defp error_kind(400), do: :bad_request
  defp error_kind(401), do: :authentication
  defp error_kind(403), do: :authorization
  defp error_kind(404), do: :not_found
  defp error_kind(409), do: :conflict
  defp error_kind(422), do: :unprocessable_entity
  defp error_kind(429), do: :rate_limit_exceeded
  defp error_kind(status) when status >= 500, do: :server
  defp error_kind(_status), do: :api

  defp generate_idempotency_key do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    c = bor(band(c, 0x0FFF), 0x4000)
    d = bor(band(d, 0x3FFF), 0x8000)

    ~c"~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b"
    |> :io_lib.format([a, b, c, d, e])
    |> to_string()
  end
end

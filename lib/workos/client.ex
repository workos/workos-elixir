# @oagen-ignore-file

defmodule WorkOS.Client do
  @moduledoc """
  HTTP client for the WorkOS API.

  ## Usage

      client = WorkOS.Client.new(api_key: "sk_...")

  The API key falls back to the `WORKOS_API_KEY` environment variable.

  ## Options for `new/1`

    * `:api_key` — API key (required unless the env var is set)
    * `:client_id` — client ID used by authentication flows and URL builders
      (falls back to the `WORKOS_CLIENT_ID` environment variable)
    * `:base_url` — override the API base URL
    * `:timeout` — receive timeout in milliseconds
    * `:max_retries` — maximum retry attempts for retryable failures
    * `:req_options` — extra `Req` options merged into every request
      (advanced; used by tests to inject `plug: {Req.Test, ...}`)
  """

  import Bitwise

  defstruct [:api_key, :client_id, :base_url, :timeout, :max_retries, :req_options]

  @type t :: %__MODULE__{
          api_key: String.t(),
          client_id: String.t() | nil,
          base_url: String.t(),
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          req_options: keyword()
        }

  @api_key_env "WORKOS_API_KEY"
  @client_id_env "WORKOS_CLIENT_ID"
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

  @doc """
  Builds a new client. See the module documentation for options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    api_key = opts[:api_key] || System.get_env(@api_key_env)

    if !(is_binary(api_key) and api_key != "") do
      raise WorkOS.ConfigurationError,
        message: "Missing API key. Pass `api_key:` to WorkOS.Client.new/1 or set WORKOS_API_KEY."
    end

    %__MODULE__{
      api_key: api_key,
      client_id: opts[:client_id] || System.get_env(@client_id_env),
      base_url: String.trim_trailing(opts[:base_url] || @default_base_url, "/"),
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

    req_options =
      [
        method: method,
        url: path,
        base_url: normalize_base_url(opts[:base_url]) || client.base_url,
        auth: {:bearer, client.api_key},
        headers: build_headers(client, method, opts, max_retries),
        receive_timeout: opts[:timeout] || client.timeout,
        retry: &retryable?/2,
        retry_delay: &retry_delay/1,
        max_retries: max_retries,
        decode_body: false
      ]
      |> put_query(query)
      |> put_body(body)

    req = Req.new(req_options) |> Req.merge(client.req_options)

    req |> Req.request() |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: status} = response})
       when status in 200..299,
       do: {:ok, decode_body(response)}

  defp handle_response({:ok, %Req.Response{} = response}), do: {:error, api_error(response)}

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

  defp user_agent, do: "workos-elixir/#{Application.spec(:workos, :vsn)}"

  defp retryable?(_request, %Req.Response{status: status}),
    do: status in @retryable_status_codes

  defp retryable?(_request, %Req.TransportError{}), do: true
  defp retryable?(_request, _other), do: false

  defp retry_delay(attempt) do
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

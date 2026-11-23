# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.GitHubActions do
  @moduledoc """
  Identity token provider for GitHub Actions.

  `github_actions/1` returns a provider: a zero-arity function that asks the
  runner's OIDC endpoint for a token with the given audience and returns
  `{:ok, token}` or `{:error, %WorkOS.WorkloadIdentity.GitHubActions.Error{}}`.

  The workflow or job must grant `permissions: id-token: write`.

      provider = WorkOS.WorkloadIdentity.GitHubActions.github_actions("https://api.workos.com")

      {:ok, credentials} =
        WorkOS.WorkloadIdentity.Credentials.start_link(
          client_id: "client_...",
          environment_id: "environment_...",
          token_url: "https://.../oauth2/token",
          identity_token_provider: provider
        )

  The provider holds no cache and does not retry; the WorkOS SDK retries it as
  part of the token exchange. The token is never logged and never placed in
  an error.
  """

  defmodule Error do
    @moduledoc """
    Returned when the GitHub Actions OIDC token could not be fetched.
    """

    defexception [:message]

    @type t :: %__MODULE__{message: String.t()}
  end

  @url_env "ACTIONS_ID_TOKEN_REQUEST_URL"
  @token_env "ACTIONS_ID_TOKEN_REQUEST_TOKEN"
  @timeout_ms 10_000

  @missing_env_message "GitHub Actions did not provide an OIDC token endpoint. " <>
                         "Add `permissions: id-token: write` to the workflow or job."

  @unsendable_token_message "#{@token_env} contains a character that is not allowed in an " <>
                              "HTTP header, such as a line break. GitHub Actions sets this " <>
                              "variable; pass it to the program unchanged."

  @type provider :: (-> {:ok, String.t()} | {:error, Error.t()})

  @doc """
  Returns an identity token provider for the given audience.

  The audience is required. The conventional value is `https://api.workos.com`.
  `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` are read
  on every call of the provider, not when it is built. A request token with a
  space, a line break, any other control character or a character outside
  ASCII is refused before any request is made.
  """
  @spec github_actions(String.t()) :: provider()
  def github_actions(audience) when is_binary(audience) and audience != "" do
    fn -> fetch(audience) end
  end

  defp fetch(audience) do
    with {:ok, url, request_token} <- endpoint(),
         {:ok, body} <- get(with_audience(url, audience), request_token) do
      parse(body)
    end
  end

  defp endpoint do
    url = System.get_env(@url_env)
    request_token = System.get_env(@token_env)

    cond do
      url in [nil, ""] or request_token in [nil, ""] -> error(@missing_env_message)
      not visible_ascii?(request_token) -> error(@unsendable_token_message)
      true -> {:ok, url, request_token}
    end
  end

  # The request token goes into a header as it is, and `:httpc` sends a line
  # break or any other control character in a header value unchanged: a
  # trailing newline breaks the header, and a line break followed by text adds
  # a header of its own. So only visible ASCII, 0x21 to 0x7E, is accepted.
  # Nothing is stripped: a token that needs repair is not the runner's token.
  defp visible_ascii?(request_token), do: request_token =~ ~r/\A[\x21-\x7E]+\z/

  # The runner's URL already has a query string; the audience is added to it.
  defp with_audience(url, audience) do
    url
    |> URI.parse()
    |> URI.append_query("audience=" <> URI.encode(audience, &URI.char_unreserved?/1))
    |> URI.to_string()
  end

  defp get(url, request_token) do
    headers = [
      {~c"authorization", String.to_charlist("Bearer " <> request_token)},
      {~c"accept", ~c"application/json"}
    ]

    http_options =
      [timeout: @timeout_ms, connect_timeout: @timeout_ms, autoredirect: false] ++
        ssl_options(url)

    case :httpc.request(:get, {String.to_charlist(url), headers}, http_options,
           body_format: :binary
         ) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_version, status, _reason}, _headers, _body}} ->
        error("The GitHub Actions OIDC token endpoint returned HTTP #{status}.")

      {:error, reason} ->
        error(
          "The GitHub Actions OIDC token endpoint#{at(url)} could not be reached: " <>
            "#{describe(reason)}."
        )
    end
  end

  # Where the request went, as " at host:port". No other part of the URL is
  # named, and nothing is added when the URL has no host or no known port.
  defp at(url) do
    case URI.parse(url) do
      %URI{host: host, port: port} when is_binary(host) and host != "" and is_integer(port) ->
        " at #{host}:#{port}"

      _no_host_or_port ->
        ""
    end
  end

  # Verify the endpoint's certificate against the operating system's trust
  # store. OTP releases before 26 do not verify unless told to.
  defp ssl_options("https://" <> _rest) do
    [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 10,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]
  end

  defp ssl_options(_url), do: []

  defp parse(body) do
    case JSON.decode(body) do
      {:ok, %{"value" => value}} when is_binary(value) and value != "" ->
        {:ok, value}

      _other ->
        error(
          "The GitHub Actions OIDC token endpoint response had no token in its `value` field."
        )
    end
  end

  # The wording of a failed request is a test seam: most of these failures
  # cannot be produced on a loopback port. It is not a public function.
  @doc false
  @spec __describe__(term()) :: String.t()
  def __describe__(reason), do: describe(reason)

  # Only the failure kind is reported, in fixed words. Nothing raw is
  # interpolated: not the reason, not a TLS alert's text, not a header, and no
  # part of the URL other than its host and port. So nothing from the request
  # can end up in the message. The only terms printed are an atom the socket
  # gave as the reason and the name of a TLS alert.
  defp describe({:failed_connect, info}) when is_list(info) do
    case List.keyfind(info, :inet, 0) || List.keyfind(info, :inet6, 0) do
      {_family, _options, reason} -> known_failure(reason) || connection_failed(reason)
      _other -> "the connection failed"
    end
  end

  defp describe(reason), do: known_failure(reason) || "the request failed"

  defp connection_failed(reason) when is_atom(reason), do: "the connection failed (#{reason})"
  defp connection_failed(_reason), do: "the connection failed"

  # The failures that get words of their own, or `nil`. A timeout and a closed
  # connection can come from the connection attempt or from the request.
  defp known_failure(:nxdomain), do: "the host name could not be resolved (nxdomain)"
  defp known_failure(:econnrefused), do: "the connection was refused (econnrefused)"

  defp known_failure(reason) when reason in [:timeout, :etimedout],
    do: "the request timed out (#{reason})"

  defp known_failure(reason) when reason in [:closed, :socket_closed_remotely],
    do: "the server closed the connection (#{reason})"

  defp known_failure({:tls_alert, {alert, text}}), do: tls_failure(alert, text)
  defp known_failure({:tls_alert, _other}), do: "the TLS handshake failed"
  defp known_failure(_reason), do: nil

  # A certificate for another host name and a self-signed certificate arrive
  # under a general alert, and which alert depends on the OTP release. They
  # are told apart by the fixed word OTP puts in the alert's text. The text is
  # only searched; it is never copied into the message.
  defp tls_failure(alert, text) do
    cond do
      mentions?(text, "hostname_check_failed") ->
        "the server's certificate is for another host name (hostname_check_failed)"

      mentions?(text, "selfsigned_peer") ->
        "the server's certificate is self-signed (selfsigned_peer)"

      alert == :unknown_ca ->
        "the server's certificate is not from a trusted certificate authority (unknown_ca)"

      alert == :certificate_expired ->
        "the server's certificate has expired or is not valid yet (certificate_expired)"

      is_atom(alert) ->
        "the TLS handshake failed (#{alert})"

      true ->
        "the TLS handshake failed"
    end
  end

  defp mentions?(text, word) when is_list(text) or is_binary(text) do
    text |> IO.chardata_to_string() |> String.contains?(word)
  rescue
    _not_text -> false
  end

  defp mentions?(_text, _word), do: false

  defp error(message), do: {:error, %Error{message: message}}
end

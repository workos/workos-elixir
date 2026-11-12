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

  @type provider :: (-> {:ok, String.t()} | {:error, Error.t()})

  @doc """
  Returns an identity token provider for the given audience.

  The audience is required. The conventional value is `https://api.workos.com`.
  `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` are read
  on every call of the provider, not when it is built.
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

    if url in [nil, ""] or request_token in [nil, ""] do
      error(@missing_env_message)
    else
      {:ok, url, request_token}
    end
  end

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
        error("The GitHub Actions OIDC token endpoint could not be reached: #{describe(reason)}.")
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

  # Only the failure kind is reported. The raw reason is never interpolated,
  # so nothing from the request can end up in the message.
  defp describe(:timeout), do: "timeout"

  defp describe({:failed_connect, info}) when is_list(info) do
    case List.keyfind(info, :inet, 0) || List.keyfind(info, :inet6, 0) do
      {_family, _options, reason} when is_atom(reason) -> "connection failed (#{reason})"
      _other -> "connection failed"
    end
  end

  defp describe(_reason), do: "request failed"

  defp error(message), do: {:error, %Error{message: message}}
end

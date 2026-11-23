# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity.GCP do
  @moduledoc """
  Identity token provider for Google Cloud.

  `gcp_metadata/1` returns a provider: a zero-arity function that asks the
  metadata server for an identity token of the attached service account, with
  the given audience, and returns `{:ok, token}` or
  `{:error, %WorkOS.WorkloadIdentity.GCP.Error{}}`.

  It works wherever the metadata server is reachable: Compute Engine, GKE,
  Cloud Run, Cloud Functions and App Engine.

      provider = WorkOS.WorkloadIdentity.GCP.gcp_metadata("https://api.workos.com")

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

  The request to the metadata server never goes through a proxy, even when
  the application has given `:httpc` one with `:httpc.set_options/1`.
  """

  defmodule Error do
    @moduledoc """
    Returned when the metadata server's identity token could not be fetched.
    """

    defexception [:message]

    @type t :: %__MODULE__{message: String.t()}
  end

  @metadata_base_url "http://metadata.google.internal"
  @identity_path "/computeMetadata/v1/instance/service-accounts/default/identity"
  @timeout_ms 10_000

  # The provider's own `:httpc` profile. The default profile is shared with
  # the application, which may have given it a proxy (`:httpc.set_options/1`).
  # The metadata server is an address inside the workload's own VM or
  # container. A proxy is another machine: it cannot reach that server, and it
  # could answer with its own identity. Nothing ever sets a proxy on this
  # profile, so the request always goes direct.
  @httpc_profile :workos_workload_identity_gcp

  @type provider :: (-> {:ok, String.t()} | {:error, Error.t()})

  @doc """
  Returns an identity token provider for the given audience.

  The audience is required. The conventional value is `https://api.workos.com`.
  """
  @spec gcp_metadata(String.t()) :: provider()
  def gcp_metadata(audience), do: __provider__(audience, @metadata_base_url)

  # The base URL is a test seam. It is not a public option and is not read
  # from the environment.
  @doc false
  @spec __provider__(String.t(), String.t()) :: provider()
  def __provider__(audience, base_url) when is_binary(audience) and audience != "" do
    fn -> fetch(audience, base_url) end
  end

  defp fetch(audience, base_url) do
    url =
      base_url <>
        @identity_path <>
        "?audience=" <> URI.encode(audience, &URI.char_unreserved?/1) <> "&format=full"

    headers = [{~c"metadata-flavor", ~c"Google"}]
    http_options = [timeout: @timeout_ms, connect_timeout: @timeout_ms, autoredirect: false]

    with :ok <- ensure_profile(),
         {:ok, {{_version, 200, _reason}, _headers, body}} <-
           :httpc.request(
             :get,
             {String.to_charlist(url), headers},
             http_options,
             [body_format: :binary],
             @httpc_profile
           ) do
      token(body)
    else
      {:ok, {{_version, status, _reason}, _headers, _body}} ->
        error("The Google Cloud metadata server returned HTTP #{status}.")

      {:error, reason} ->
        error("The Google Cloud metadata server could not be reached: #{describe(reason)}.")
    end
  end

  # Starts the profile on first use. It runs under `:inets`, so it outlives
  # the calling process; later calls find it already started.
  defp ensure_profile do
    case :inets.start(:httpc, profile: @httpc_profile) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, _reason} -> {:error, :profile_not_started}
    end
  end

  defp token(body) do
    case String.trim(body) do
      "" -> error("The Google Cloud metadata server returned an empty identity token.")
      token -> {:ok, token}
    end
  end

  # Only the failure kind is reported. The raw reason is never interpolated.
  defp describe(:timeout), do: "timeout"

  defp describe({:failed_connect, info}) when is_list(info) do
    case List.keyfind(info, :inet, 0) || List.keyfind(info, :inet6, 0) do
      {_family, _options, reason} when is_atom(reason) -> "connection failed (#{reason})"
      _other -> "connection failed"
    end
  end

  defp describe(:profile_not_started), do: "the HTTP client did not start"
  defp describe(_reason), do: "request failed"

  defp error(message), do: {:error, %Error{message: message}}
end

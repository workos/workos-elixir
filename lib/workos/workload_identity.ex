# @oagen-ignore-file

defmodule WorkOS.WorkloadIdentity do
  @moduledoc """
  Workload identity federation: authenticate to WorkOS with the identity your
  platform already gives the workload, instead of a stored API key.

  An identity token provider returns the workload's JWT. The SDK exchanges it
  for a short-lived WorkOS access token, caches the token, and refreshes it
  before it expires. See `WorkOS.WorkloadIdentity.Credentials` to set it up.

  ## Identity token providers

  A provider is a zero-arity function, or a `{module, function, args}` tuple,
  that returns `{:ok, token}` or `{:error, reason}`. It is called again for
  every exchange attempt, so it needs no cache and no retries of its own.

  This module has the two providers that read a token another process has
  already written somewhere: `token_file/1` and `token_env/1`. Any function of
  the same shape works as a custom provider:

      provider = fn -> MyApp.Vault.fetch_jwt() end

  Providers for GitHub Actions, Google Cloud and AWS are separate packages:
  `workos_workload_identity_github_actions`, `workos_workload_identity_gcp`
  and `workos_workload_identity_aws`.
  """

  @typedoc """
  Returns the workload's identity token.
  """
  @type identity_token_provider ::
          (-> {:ok, String.t()} | {:error, term()}) | {module(), atom(), [term()]}

  @doc """
  Returns a provider that reads the token from a file: one that another
  process writes, such as a sidecar or an earlier CI step that fetches a new
  token.

  The file is read again on every call, so a rotated token is picked up.
  Surrounding whitespace is trimmed. A missing or empty file is an error.

      WorkOS.WorkloadIdentity.token_file("/run/workos/identity-token")
  """
  @spec token_file(Path.t()) :: (-> {:ok, String.t()} | {:error, String.t()})
  def token_file(path) when is_binary(path), do: fn -> read_file(path) end

  @doc """
  Returns a provider that reads the token from an environment variable.

  The variable is read again on every call. An unset or empty variable is an
  error.

      WorkOS.WorkloadIdentity.token_env("MY_IDENTITY_TOKEN")
  """
  @spec token_env(String.t()) :: (-> {:ok, String.t()} | {:error, String.t()})
  def token_env(name) when is_binary(name), do: fn -> read_env(name) end

  defp read_file(path) do
    case File.read(path) do
      {:ok, contents} -> file_token(String.trim(contents), path)
      {:error, reason} -> {:error, "identity token file #{path} could not be read: #{reason}"}
    end
  end

  defp file_token("", path), do: {:error, "identity token file #{path} is empty"}
  defp file_token(token, _path), do: {:ok, token}

  defp read_env(name) do
    case System.get_env(name) do
      token when is_binary(token) and token != "" -> {:ok, token}
      _unset_or_empty -> {:error, "environment variable #{name} is not set or is empty"}
    end
  end
end

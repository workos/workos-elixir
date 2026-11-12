# @oagen-ignore-file

defmodule WorkOS.Credentials.StaticKey do
  @moduledoc """
  `WorkOS.Credentials` for a static API key.

  The key is sent as a bearer token on every attempt. A 401 is never
  recovered, because resolving again would return the same key.
  """

  @behaviour WorkOS.Credentials

  @impl WorkOS.Credentials
  def resolve(api_key, _timeout) when is_binary(api_key) do
    {:ok,
     %WorkOS.CredentialSnapshot{
       headers: [{"authorization", "Bearer " <> api_key}],
       generation: 0,
       recoverable: false
     }}
  end

  @impl WorkOS.Credentials
  def invalidate(_api_key, _generation), do: :ok
end

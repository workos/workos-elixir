# @oagen-ignore-file

defmodule WorkOS.Credentials do
  @moduledoc """
  The contract every `WorkOS.Client` authenticates through.

  Two operations:

    * `c:resolve/2` returns the `WorkOS.CredentialSnapshot` to send one HTTP
      attempt with. It may wait, up to the given timeout.
    * `c:invalidate/2` marks the credential behind a generation as rejected.
      It never waits on the network.

  The SDK ships two implementations. A static API key is
  `WorkOS.Credentials.StaticKey`: one fixed header, never recoverable.
  Workload identity federation is `WorkOS.WorkloadIdentity.Credentials`: a
  short-lived access token that is exchanged, cached and refreshed by a
  process the application starts.
  """

  @typedoc """
  An implementing module and the value its callbacks take.
  """
  @type t :: {module(), term()}

  @callback resolve(credentials :: term(), timeout()) ::
              {:ok, WorkOS.CredentialSnapshot.t()} | {:error, Exception.t()}

  @callback invalidate(credentials :: term(), generation :: term()) :: :ok

  @doc false
  @spec resolve(t(), timeout()) :: {:ok, WorkOS.CredentialSnapshot.t()} | {:error, Exception.t()}
  def resolve({module, credentials}, timeout), do: module.resolve(credentials, timeout)

  @doc false
  @spec invalidate(t(), term()) :: :ok
  def invalidate({module, credentials}, generation),
    do: module.invalidate(credentials, generation)
end

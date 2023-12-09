defmodule WorkOS.MFA.VerifyChallenge do
  @moduledoc """
  This response struct is deprecated. Use the User Management Multi-Factor API instead.
  """

  @behaviour WorkOS.Castable

  alias WorkOS.MFA.AuthenticationChallenge

  @type t() :: %__MODULE__{
          challenge: AuthenticationChallenge.t(),
          valid: boolean()
        }

  @enforce_keys [:challenge, :valid]
  defstruct [
    :challenge,
    :valid
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      challenge: map["challenge"],
      valid: map["valid"]
    }
  end
end

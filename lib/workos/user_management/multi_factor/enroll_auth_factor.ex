defmodule WorkOS.UserManagement.MultiFactor.EnrollAuthFactor do
  @moduledoc """
  WorkOS Enroll Auth Factor struct.
  """

  alias WorkOS.UserManagement.MultiFactor.AuthenticationChallenge
  alias WorkOS.UserManagement.MultiFactor.AuthenticationFactor

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          challenge: AuthenticationChallenge.t(),
          factor: AuthenticationFactor.t()
        }

  @enforce_keys [
    :challenge,
    :factor
  ]
  defstruct [
    :challenge,
    :factor
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      challenge: map["challenge"],
      factor: map["factor"]
    }
  end
end

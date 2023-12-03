defmodule WorkOS.UserManagement.EmailVerification.VerifyEmail do
  @moduledoc """
  WorkOS Verify Email Code struct.
  """

  alias WorkOS.UserManagement.User

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          user: User.t()
        }

  @enforce_keys [
    :user
  ]
  defstruct [
    :user
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      user: map["user"]
    }
  end
end

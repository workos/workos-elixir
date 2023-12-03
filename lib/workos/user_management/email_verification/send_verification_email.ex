defmodule WorkOS.UserManagement.EmailVerification.SendVerificationEmail do
  @moduledoc """
  WorkOS Send Email struct.
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

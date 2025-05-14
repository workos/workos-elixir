defmodule WorkOS.UserManagement.ResetPassword do
  @moduledoc """
  WorkOS Reset Password struct.
  """

  alias WorkOS.UserManagement.User

  @type t() :: %__MODULE__{
          user: User.t()
        }

  @enforce_keys [
    :user
  ]
  defstruct [
    :user
  ]

  def cast(params) do
    %__MODULE__{
      user: params["user"]
    }
  end
end

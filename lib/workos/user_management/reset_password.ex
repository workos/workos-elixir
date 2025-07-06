defmodule WorkOS.UserManagement.ResetPassword do
  @moduledoc """
  WorkOS Reset Password struct.
  """

  alias WorkOS.UserManagement.User

  @behaviour WorkOS.Castable
  @behaviour WorkOS.Mappable

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
  def cast(params) do
    %__MODULE__{
      user: params["user"]
    }
  end

  @impl true
  def to_map(%__MODULE__{} = reset_password) do
    Map.from_struct(reset_password)
  end
end

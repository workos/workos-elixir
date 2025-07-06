defmodule WorkOS.UserManagement.User do
  @moduledoc """
  WorkOS User struct.
  """

  @behaviour WorkOS.Castable
  @behaviour WorkOS.Mappable

  @type t() :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          email_verified: boolean(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [
    :id,
    :email,
    :email_verified,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :email,
    :email_verified,
    :first_name,
    :last_name,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(params) do
    %__MODULE__{
      id: params["id"],
      email: params["email"],
      email_verified: params["email_verified"],
      first_name: params["first_name"],
      last_name: params["last_name"],
      updated_at: params["updated_at"],
      created_at: params["created_at"]
    }
  end

  @impl true
  def to_map(%__MODULE__{} = user) do
    Map.from_struct(user)
  end
end

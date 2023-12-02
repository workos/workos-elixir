defmodule WorkOS.UserManagement.User do
  @moduledoc """
  WorkOS User struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          email_verified: Boolean.t(),
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
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      email: map["email"],
      email_verified: map["email_verified"],
      first_name: map["first_name"],
      last_name: map["last_name"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end

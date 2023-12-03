defmodule WorkOS.UserManagement.Invitation do
  @moduledoc """
  WorkOS Invitation struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          state: String.t(),
          token: String.t(),
          organization_id: String.t() | nil,
          accepted_at: String.t() | nil,
          expires_at: String.t() | nil,
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [
    :id,
    :email,
    :state,
    :token,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :email,
    :state,
    :token,
    :organization_id,
    :accepted_at,
    :expires_at,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      email: map["email"],
      state: map["state"],
      token: map["token"],
      organization_id: map["organization_id"],
      accepted_at: map["accepted_at"],
      expires_at: map["expires_at"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end

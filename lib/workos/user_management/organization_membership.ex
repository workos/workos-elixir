defmodule WorkOS.UserManagement.OrganizationMembership do
  @moduledoc """
  WorkOS Organization Membership struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          organization_id: String.t(),
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [
    :id,
    :user_id,
    :organization_id,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :user_id,
    :organization_id,
    :updated_at,
    :created_at
  ]

  def cast(params) do
    %__MODULE__{
      id: params["id"],
      user_id: params["user_id"],
      organization_id: params["organization_id"],
      updated_at: params["updated_at"],
      created_at: params["created_at"]
    }
  end
end

defmodule WorkOS.SSO.Connection do
  @moduledoc """
  WorkOS Connection struct.
  """

  alias WorkOS.Castable
  alias WorkOS.SSO.Connection.Domain

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          connection_type: String.t(),
          state: String.t(),
          domains: list(Domain.t()) | nil,
          updated_at: String.t(),
          created_at: String.t(),
          organization_id: String.t()
        }

  @enforce_keys [:id, :name, :connection_type, :state, :updated_at, :created_at, :organization_id]
  defstruct [
    :id,
    :name,
    :connection_type,
    :state,
    :domains,
    :updated_at,
    :created_at,
    :organization_id
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      name: map["name"],
      connection_type: map["connection_type"],
      state: map["state"],
      domains: Castable.cast_list(Domain, map["domains"]),
      updated_at: map["updated_at"],
      created_at: map["created_at"],
      organization_id: map["organization_id"]
    }
  end
end

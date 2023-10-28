defmodule WorkOS.SSO.Connection do
  @moduledoc """
  WorkOS Connection struct.
  """

  alias WorkOS.Util
  alias WorkOS.Castable
  alias WorkOS.SSO.Connection.Domain

  @behaviour Resend.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          # TODO - Add type for connection type
          type: String.t() | nil,
          # TODO - Add type for connection state
          state: String.t() | nil,
          domains: list(Record.t()) | nil,
          updated_at: DateTime.t(),
          created_at: DateTime.t(),
          organization_id: String.t()
        }

  @enforce_keys [:id]
  defstruct [
    :id,
    :name,
    :type,
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
      type: map["type"],
      name: map["name"],
      records: Castable.cast_list(Domain, map["domains"]),
      updated_at: Util.parse_iso8601(map["created_at"]),
      created_at: Util.parse_iso8601(map["created_at"]),
      organization_id: map["organization_id"]
    }
  end
end

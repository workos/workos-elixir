defmodule WorkOS.DirectorySync.Directory.Group do
  @moduledoc """
  WorkOS Directory Group struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          idp_id: String.t(),
          directory_id: String.t(),
          organization_id: String.t() | nil,
          raw_attributes: %{String.t() => any()},
          updated_at: DateTime.t(),
          created_at: DateTime.t()
        }

  @enforce_keys [
    :id,
    :name,
    :idp_id,
    :directory_id,
    :raw_attributes,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :name,
    :idp_id,
    :directory_id,
    :updated_at,
    :created_at,
    :raw_attributes,
    :organization_id
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      name: map["name"],
      idp_id: map["idp_id"],
      directory_id: map["directory_id"],
      organization_id: map["organization_id"],
      raw_attributes: map["raw_attributes"],
      updated_at: map["created_at"],
      created_at: map["created_at"]
    }
  end
end

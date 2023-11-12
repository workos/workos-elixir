defmodule WorkOS.DirectorySync.Directory do
  @moduledoc """
  WorkOS Directory struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          object: String.t(),
          external_key: String.t(),
          state: String.t(),
          updated_at: DateTime.t(),
          created_at: DateTime.t(),
          name: String.t(),
          domain: String.t(),
          organization_id: String.t() | nil,
          type: String.t()
        }

  @enforce_keys [
    :id,
    :object,
    :external_key,
    :state,
    :updated_at,
    :created_at,
    :name,
    :domain,
    :type
  ]
  defstruct [
    :id,
    :object,
    :external_key,
    :state,
    :updated_at,
    :created_at,
    :name,
    :domain,
    :organization_id,
    :type
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      type: map["type"],
      external_key: map["external_key"],
      state: map["state"],
      name: map["name"],
      organization_id: map["organization_id"],
      domain: map["domain"],
      updated_at: map["created_at"],
      created_at: map["created_at"]
    }
  end
end

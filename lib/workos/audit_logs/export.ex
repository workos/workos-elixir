defmodule WorkOS.AuditLogs.Export do
  @moduledoc """
  WorkOS Audit Logs Export struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          object: String.t(),
          state: String.t(),
          url: String.t() | nil,
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [:id, :object, :state, :updated_at, :created_at]
  defstruct [
    :id,
    :object,
    :state,
    :url,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      state: map["state"],
      url: map["url"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end

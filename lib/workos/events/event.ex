defmodule WorkOS.Events.Event do
  @moduledoc """
  WorkOS Event struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          event: String.t(),
          data: map(),
          created_at: String.t()
        }

  @enforce_keys [:id, :event, :created_at]
  defstruct [
    :id,
    :event,
    :data,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      data: map["data"],
      event: map["event"],
      created_at: map["created_at"]
    }
  end
end

defmodule WorkOS.SSO.Connection.Domain do
  @moduledoc """
  WorkOS Domain Record struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          domain: String.t()
        }

  @enforce_keys [:id]
  defstruct [
    :id,
    :domain
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      domain: map["domain"]
    }
  end
end

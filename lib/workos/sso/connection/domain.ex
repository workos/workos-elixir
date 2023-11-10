defmodule WorkOS.SSO.Connection.Domain do
  @moduledoc """
  WorkOS Domain Record struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          object: String.t(),
          domain: String.t()
        }

  @enforce_keys [:id]
  defstruct [
    :id,
    :object,
    :domain
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      domain: map["domain"]
    }
  end
end

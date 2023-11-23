defmodule WorkOS.Organizations.Organization.Domain do
  @moduledoc """
  WorkOS Organization Domain struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          object: String.t(),
          domain: String.t()
        }

  @enforce_keys [:id, :object, :domain]
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

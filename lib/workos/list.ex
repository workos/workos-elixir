defmodule WorkOS.List do
  @moduledoc """
  Casts a response to a `%WorkOS.List{}` of structs.
  """

  alias WorkOS.Castable

  @behaviour WorkOS.Castable

  @type t(g) :: %__MODULE__{
          data: list(g),
          list_metadata: map()
        }

  @enforce_keys [:data, :list_metadata]
  defstruct [:data, :list_metadata]

  @impl true
  def cast({implementation, map}) do
    %__MODULE__{
      data: Castable.cast_list(implementation, map["data"]),
      list_metadata: map["list_metadata"]
    }
  end

  def of(implementation) do
    {__MODULE__, implementation}
  end
end

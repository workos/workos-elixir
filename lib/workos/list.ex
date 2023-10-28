defmodule WorkOS.List do
  @moduledoc """
  Casts a response to a `%WorkOS.List{}` of structs.
  """

  alias WorkOS.Castable

  @behaviour WorkOS.Castable

  @type t(g) :: %__MODULE__{
          data: list(g)
        }

  @enforce_keys [:data]
  defstruct [:data]

  @impl true
  def cast({implementation, map}) do
    %__MODULE__{
      data: Castable.cast_list(implementation, map["data"])
    }
  end

  def of(implementation) do
    {__MODULE__, implementation}
  end
end

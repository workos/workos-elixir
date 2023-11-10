defmodule WorkOS.Empty do
  @moduledoc """
  Empty response.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{}

  defstruct []

  @impl true
  def cast(_map), do: %__MODULE__{}
end

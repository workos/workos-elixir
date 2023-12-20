defmodule WorkOS.Empty do
  @moduledoc """
  Empty response.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{status: String.t()} | :accepted

  defstruct [:status]

  @impl true
  def cast(_map), do: %__MODULE__{}
  def cast(__MODULE__, "Accepted"), do: %__MODULE__{status: "Accepted"}
end

defmodule WorkOS.Castable do
  @moduledoc """
  Defines the Castable protocol for WorkOS SDK, used for casting API responses to Elixir structs.

  This module provides the `cast/2` and `cast_list/2` functions, as well as the `impl` type used throughout the SDK for flexible casting.
  """

  @typedoc """
  Represents a castable implementation. This can be a module, a tuple of modules, or :raw for raw maps.
  """
  @type impl :: module() | {module(), module()} | :raw
  @type generic_map :: %{String.t() => any()}

  @callback cast(generic_map() | {module(), generic_map()} | nil) :: struct() | nil

  @spec cast(impl(), generic_map() | nil) :: struct() | generic_map() | nil
  def cast(_implementation, nil) do
    nil
  end

  def cast(:raw, generic_map) do
    generic_map
  end

  def cast({implementation, inner}, generic_map) when is_map(generic_map) do
    implementation.cast({inner, generic_map})
  end

  def cast(implementation, generic_map) when is_map(generic_map) do
    implementation.cast(generic_map)
  end

  def cast(WorkOS.Empty, "Accepted"), do: %WorkOS.Empty{status: "Accepted"}

  @spec cast_list(module(), [generic_map()] | nil) :: [struct()] | nil
  def cast_list(_implementation, nil) do
    nil
  end

  def cast_list(implementation, list_of_generic_maps) when is_list(list_of_generic_maps) do
    Enum.map(list_of_generic_maps, &cast(implementation, &1))
  end
end

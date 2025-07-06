defmodule WorkOS.Mappable do
  @moduledoc """
  Defines the Mappable protocol for WorkOS SDK, used for converting Elixir structs to maps.

  This protocol provides a standard way to convert WorkOS structs to plain maps,
  which is useful for JSON serialization, API responses, or any other case where
  you need a map representation of a struct.
  """

  @doc """
  Converts a struct to a map representation.
  """
  @callback to_map(struct()) :: map()

  @doc """
  Converts a struct to a map representation.
  """
  @spec to_map(struct()) :: map()
  def to_map(struct) do
    struct.__struct__.to_map(struct)
  end

  @doc """
  Converts a list of structs to a list of maps.
  """
  @spec to_map_list([struct()]) :: [map()]
  def to_map_list(structs) when is_list(structs) do
    Enum.map(structs, &to_map/1)
  end

  def to_map_list(nil), do: nil
end

# @oagen-ignore-file

defmodule WorkOS.Cast do
  @moduledoc """
  Nil-safe casting helpers used by generated `from_map/1` and `to_map/1`
  functions. Unexpected shapes pass through unchanged (lenient casting), so
  new or malformed API payloads never crash the SDK.
  """

  @doc "Casts each element of a list with `fun`; non-lists pass through."
  @spec list(term(), (term() -> term())) :: term()
  def list(values, fun) when is_list(values), do: Enum.map(values, fun)
  def list(other, _fun), do: other

  @doc "Casts a nested map with `fun`; non-maps pass through."
  @spec nested(term(), (map() -> term())) :: term()
  def nested(value, fun) when is_map(value), do: fun.(value)
  def nested(other, _fun), do: other

  @doc "Applies an enum cast/dump function; nil passes through."
  @spec enum(term(), (term() -> term())) :: term()
  def enum(nil, _fun), do: nil
  def enum(value, fun), do: fun.(value)

  @doc "Casts each value of a map with `fun`; non-maps pass through."
  @spec map_values(term(), (term() -> term())) :: term()
  def map_values(map, fun) when is_map(map), do: Map.new(map, fn {k, v} -> {k, fun.(v)} end)
  def map_values(other, _fun), do: other

  @doc """
  Dispatches a discriminated-union map to the caster for its discriminator
  value. Unknown discriminator values (and non-maps) pass through unchanged.
  """
  @spec discriminated(term(), String.t(), %{optional(String.t()) => (map() -> term())}) :: term()
  def discriminated(map, property, mapping) when is_map(map) do
    case Map.fetch(mapping, Map.get(map, property)) do
      {:ok, fun} -> fun.(map)
      :error -> map
    end
  end

  def discriminated(other, _property, _mapping), do: other

  @doc "Dumps a struct with `fun`; nil and already-plain values pass through."
  @spec dump_struct(term(), (struct() -> map())) :: term()
  def dump_struct(%_{} = value, fun), do: fun.(value)
  def dump_struct(other, _fun), do: other

  @doc "Drops nil-valued entries from a map."
  @spec drop_nils(map()) :: map()
  def drop_nils(map) when is_map(map) do
    map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
  end
end

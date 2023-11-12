defmodule WorkOS.Webhooks.Event do
  @moduledoc """
  Module to represent a webhook event
  """

  defstruct [:id, :event, :data]

  @spec new(payload :: String.t()) :: __MODULE__
  def new(payload) do
    processed_map =
      [:id, :event, :data]
      |> Enum.reduce(%{}, fn key, acc ->
        string_key = to_string(key)
        converted_value = Map.get(payload, string_key) |> convert_value()
        Map.put(acc, key, converted_value)
      end)

    struct(%__MODULE__{}, processed_map)
  end

  defp convert_value(value) when is_map(value), do: convert_map(value)
  defp convert_value(value) when is_list(value), do: convert_list(value)
  defp convert_value(value), do: value

  defp convert_map(value) do
    Enum.reduce(value, %{}, fn {key, value}, acc ->
      Map.put(acc, String.to_atom(key), convert_value(value))
    end)
  end

  defp convert_list(list), do: list |> Enum.map(&convert_value/1)
end

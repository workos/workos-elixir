defmodule WorkOS.Webhooks.Event do
  @moduledoc """
  Module to represent a webhook event
  """

  defstruct [:id, :event, :data]

  @spec new(map) :: %__MODULE__{}
  def new(payload) do
    struct(%__MODULE__{}, %{
      id: payload["id"],
      event: payload["event"],
      data: payload["data"]
    })
  end
end

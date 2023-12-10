defmodule WorkOS.Events do
  @moduledoc """
  Manage Events API in WorkOS.

  @see https://workos.com/docs/events
  """

  alias WorkOS.Events.Event

  @doc """
  Lists all events.

  Parameter options:

    * `:events` - Filter to only return events of particular types.
    * `:range_start` - Date range start for stream of events.
    * `:range_end` - Date range end for stream of events.
    * `:limit` - Maximum number of records to return. Accepts values between 1 and 100. Default is 10.
    * `:after` - Pagination cursor to receive records after a provided event ID.

  """
  @spec list_events(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(WorkOS.List.t(Event.t()))
  def list_events(client, opts) do
    WorkOS.Client.get(client, WorkOS.List.of(Event), "/events",
      query: [
        events: opts[:events],
        range_start: opts[:range_start],
        range_end: opts[:range_end],
        limit: opts[:limit],
        after: opts[:after]
      ]
    )
  end

  @spec list_events(map()) ::
          WorkOS.Client.response(WorkOS.List.t(Event.t()))
  def list_events(opts \\ %{}) do
    WorkOS.Client.get(WorkOS.client(), WorkOS.List.of(Event), "/events",
      query: [
        events: opts[:events],
        range_start: opts[:range_start],
        range_end: opts[:range_end],
        limit: opts[:limit],
        after: opts[:after]
      ]
    )
  end
end

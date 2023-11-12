defmodule WorkOS.EventsTest do
  use WorkOS.TestCase

  alias WorkOS.Events.ClientMock

  setup :setup_env

  describe "list_events" do
    test "requests events", context do
      opts = [events: ["connection.activated"]]

      context |> ClientMock.list_events(assert_fields: opts)

      assert {:ok, %WorkOS.List{data: [%WorkOS.Events.Event{}], list_metadata: %{}}} =
               WorkOS.Events.list_events(opts |> Enum.into(%{}))
    end
  end
end

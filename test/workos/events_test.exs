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

  describe "WorkOS.Events.Event struct and cast" do
    test "struct creation" do
      event = %WorkOS.Events.Event{
        id: "event_123",
        event: "connection.activated",
        data: %{foo: "bar"},
        created_at: "2024-01-01T00:00:00Z"
      }

      assert event.id == "event_123"
      assert event.event == "connection.activated"
      assert event.data == %{foo: "bar"}
      assert event.created_at == "2024-01-01T00:00:00Z"
    end

    test "cast/1" do
      map = %{
        "id" => "event_123",
        "event" => "connection.activated",
        "data" => %{foo: "bar"},
        "created_at" => "2024-01-01T00:00:00Z"
      }

      event = WorkOS.Events.Event.cast(map)
      assert %WorkOS.Events.Event{} = event
      assert event.id == "event_123"
      assert event.event == "connection.activated"
      assert event.data == %{foo: "bar"}
      assert event.created_at == "2024-01-01T00:00:00Z"
    end
  end

  describe "WorkOS.Events.list_events/2 and /1" do
    test "list_events/2 with explicit client" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn %{method: :get, url: url} = _req ->
        assert url =~ "/events"

        %Tesla.Env{
          status: 200,
          body: %{
            "data" => [
              %{
                "id" => "event_123",
                "event" => "connection.activated",
                "data" => %{},
                "created_at" => "2024-01-01T00:00:00Z"
              }
            ],
            "list_metadata" => %{}
          }
        }
      end)

      assert {:ok, %WorkOS.List{data: [%WorkOS.Events.Event{}], list_metadata: %{}}} =
               WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 with default client" do
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn %{method: :get, url: url} = _req ->
        assert url =~ "/events"

        %Tesla.Env{
          status: 200,
          body: %{
            "data" => [
              %{
                "id" => "event_123",
                "event" => "connection.activated",
                "data" => %{},
                "created_at" => "2024-01-01T00:00:00Z"
              }
            ],
            "list_metadata" => %{}
          }
        }
      end)

      assert {:ok, %WorkOS.List{data: [%WorkOS.Events.Event{}], list_metadata: %{}}} =
               WorkOS.Events.list_events(opts)
    end
  end

  describe "WorkOS.Events.list_events error cases" do
    test "list_events/2 with explicit client returns API error" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}
      error_body = %{"error" => "invalid_request", "message" => "Bad request"}

      Tesla.Mock.mock(fn %{method: :get, url: url} ->
        assert url =~ "/events"
        %Tesla.Env{status: 400, body: error_body}
      end)

      assert {:error, %WorkOS.Error{error: "invalid_request", message: "Bad request"}} =
               WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 with default client returns API error" do
      opts = %{events: ["connection.activated"]}
      error_body = %{"error" => "invalid_request", "message" => "Bad request"}

      Tesla.Mock.mock(fn %{method: :get, url: url} ->
        assert url =~ "/events"
        %Tesla.Env{status: 400, body: error_body}
      end)

      assert {:error, %WorkOS.Error{error: "invalid_request", message: "Bad request"}} =
               WorkOS.Events.list_events(opts)
    end

    test "list_events/2 with explicit client returns client error" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        {:error, :nxdomain}
      end)

      assert {:error, :client_error} = WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 with default client returns client error" do
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        {:error, :nxdomain}
      end)

      assert {:error, :client_error} = WorkOS.Events.list_events(opts)
    end

    test "list_events/2 returns error on 404" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 404, body: %{}}
      end)

      assert {:error, _} = WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 returns error on 404" do
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 404, body: %{}}
      end)

      assert {:error, _} = WorkOS.Events.list_events(opts)
    end

    test "list_events/2 returns error on 500" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 500, body: %{}}
      end)

      assert {:error, _} = WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 returns error on 500" do
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 500, body: %{}}
      end)

      assert {:error, _} = WorkOS.Events.list_events(opts)
    end

    test "list_events/2 returns error on 200 with binary body" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: "not a map"}
      end)

      assert {:error, "not a map"} = WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 returns error on 200 with binary body" do
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: "not a map"}
      end)

      assert {:error, "not a map"} = WorkOS.Events.list_events(opts)
    end

    test "list_events/2 returns ok on 200 with empty data" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} =
               WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 returns ok on 200 with empty data" do
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} = WorkOS.Events.list_events(opts)
    end

    test "list_events/2 returns error on 200 with empty body" do
      client = WorkOS.client()
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: ""}
      end)

      assert {:error, ""} = WorkOS.Events.list_events(client, opts)
    end

    test "list_events/1 returns error on 200 with empty body" do
      opts = %{events: ["connection.activated"]}

      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: ""}
      end)

      assert {:error, ""} = WorkOS.Events.list_events(opts)
    end
  end

  describe "WorkOS.Events.list_events edge cases" do
    test "list_events/1 with no arguments (default path)" do
      Tesla.Mock.mock(fn %{method: :get, url: url, query: query} ->
        assert url =~ "/events"
        # All query params should be nil
        assert Enum.all?(query, fn {_k, v} -> v == nil end)
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} = WorkOS.Events.list_events()
    end

    test "list_events/2 with empty map" do
      client = WorkOS.client()

      Tesla.Mock.mock(fn %{method: :get, url: url, query: query} ->
        assert url =~ "/events"
        assert Enum.all?(query, fn {_k, v} -> v == nil end)
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} =
               WorkOS.Events.list_events(client, %{})
    end

    test "list_events/2 with all options nil" do
      client = WorkOS.client()
      opts = %{events: nil, range_start: nil, range_end: nil, limit: nil, after: nil}

      Tesla.Mock.mock(fn %{method: :get, url: url, query: query} ->
        assert url =~ "/events"
        assert Enum.all?(query, fn {_k, v} -> v == nil end)
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} =
               WorkOS.Events.list_events(client, opts)
    end
  end
end

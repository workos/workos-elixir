defmodule WorkOS.Events.ClientMock do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  def list_events(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/events"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "data" => [
          %{
            "id" => "event_01234ABCD",
            "created_at" => "2020-05-06 04:21:48.649164",
            "event" => "connection.activated",
            "data" => %{
              "object" => "connection",
              "id" => "conn_01234ABCD",
              "organization_id" => "org_1234",
              "name" => "Connection",
              "connection_type" => "OktaSAML",
              "state" => "active",
              "domains" => [],
              "created_at" => "2020-05-06 04:21:48.649164",
              "updated_at" => "2020-05-06 04:21:48.649164"
            }
          }
        ],
        "list_metadata" => %{}
      }

      case Keyword.get(opts, :respond_with, {200, success_body}) do
        {:error, reason} -> {:error, reason}
        {status, body} -> %Tesla.Env{status: status, body: body}
      end
    end)
  end
end

defmodule WorkOS.Events.ClientMockTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias WorkOS.Events.ClientMock

  test "list_events/1 returns mocked response" do
    context = %{api_key: "sk_test"}
    assert is_function(ClientMock.list_events(context))
  end

  test "list_events/2 returns custom response" do
    context = %{api_key: "sk_test"}
    fun = ClientMock.list_events(context, respond_with: {201, %{foo: "bar"}})
    assert is_function(fun)
  end
end

defmodule WorkOS.Events.ClientMock do
  @moduledoc false

  use ExUnit.Case

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

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end
end

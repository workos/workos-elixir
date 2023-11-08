defmodule WorkOS.SSO.ClientMock do
  use ExUnit.Case

  def get_profile_and_token(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{client_secret: client_secret} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/sso/token"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{client_secret}"}

      body = Jason.decode!(request.body)

      for {field, value} <- Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      groups =
        case Map.get(context, :with_group_attribute, []) do
          true -> ["Admins", "Developers"]
          _ -> []
        end

      success_body = %{
        "access_token" => "01DMEK0J53CVMC32CK5SE0KZ8Q",
        "profile" => %{
          "id" => "prof_123",
          "idp_i" => "123",
          "organization_id" => "org_123",
          "connection_id" => "conn_123",
          "connection_type" => "OktaSAML",
          "email" => "foo@test.com",
          "first_name" => "foo",
          "last_name" => "bar",
          "groups" => groups,
          "raw_attributes" => %{
            "email" => "foo@test.com",
            "first_name" => "foo",
            "last_name" => "bar",
            "groups" => groups
          }
        }
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_profile(_context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      access_token = Keyword.get(opts, :assert_fields, []) |> Keyword.get(:access_token)

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/sso/profile"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{access_token}"}

      success_body = %{
        "id" => "prof_123",
        "idp_i" => "123",
        "organization_id" => "org_123",
        "connection_id" => "conn_123",
        "connection_type" => "OktaSAML",
        "email" => "foo@test.com",
        "first_name" => "foo",
        "last_name" => "bar",
        "raw_attributes" => %{
          "email" => "foo@test.com",
          "first_name" => "foo",
          "last_name" => "bar"
        }
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_connection(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{client_secret: client_secret} = context

      connection_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:connection_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/connections/#{connection_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{client_secret}"}

      success_body = %{
        "id" => connection_id,
        "organization_id" => "org_123",
        "name" => "Connection",
        "connection_type" => "OktaSAML",
        "state" => "active",
        "domains" => [],
        "created_at" => "2023-07-17T20:07:20.055Z",
        "updated_at" => "2023-07-17T20:07:20.055Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def list_connections(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{client_secret: client_secret} = context

      organization_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/connections"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{client_secret}"}

      success_body = %{
        "data" => [
          %{
            "id" => "conn_123",
            "organization_id" => organization_id,
            "name" => "Connection",
            "connection_type" => "OktaSAML",
            "state" => "active",
            "domains" => [],
            "created_at" => "2023-07-17T20:07:20.055Z",
            "updated_at" => "2023-07-17T20:07:20.055Z"
          }
        ],
        "list_metadata" => %{}
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def delete_connection(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{client_secret: client_secret} = context

      connection_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:connection_id)
      assert request.method == :delete
      assert request.url == "#{WorkOS.base_url()}/connections/#{connection_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{client_secret}"}

      {status} = Keyword.get(opts, :respond_with, {204})
      %Tesla.Env{status: status}
    end)
  end
end

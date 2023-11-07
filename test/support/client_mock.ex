defmodule WorkOS.ClientMock do
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
end

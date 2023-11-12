defmodule WorkOS.DirectorySync.ClientMock do
  @moduledoc false

  use ExUnit.Case

  def get_directory(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      directory_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:directory_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/directories/#{directory_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "id" => directory_id,
        "organization_id" => "org_123",
        "name" => "Foo",
        "domain" => "foo-corp.com",
        "object" => "directory",
        "state" => "linked",
        "external_key" => "9asBRBV",
        "type" => "okta scim v1.1",
        "created_at" => "2023-07-17T20:07:20.055Z",
        "updated_at" => "2023-07-17T20:07:20.055Z"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end
end

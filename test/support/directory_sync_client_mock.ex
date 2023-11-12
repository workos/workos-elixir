defmodule WorkOS.DirectorySync.ClientMock do
  @moduledoc false

  use ExUnit.Case

  @directory_group_response %{
    "id" => "dir_grp_123",
    "idp_id" => "123",
    "directory_id" => "dir_123",
    "organization_id" => "org_123",
    "name" => "Foo Group",
    "created_at" => "2021-10-27 15:21:50.640958",
    "updated_at" => "2021-12-13 12:15:45.531847",
    "raw_attributes" => %{
      "foo" => "bar"
    }
  }

  @directory_user_response %{
    "id" => "user_123",
    "custom_attributes" => %{
      "custom" => true
    },
    "directory_id" => "dir_123",
    "organization_id" => "org_123",
    "emails" => [
      %{
        "primary" => true,
        "type" => "type",
        "value" => "jonsnow@workos.com"
      }
    ],
    "first_name" => "Jon",
    "groups" => [@directory_group_response],
    "idp_id" => "idp_foo",
    "last_name" => "Snow",
    "job_title" => "Knight of the Watch",
    "raw_attributes" => %{},
    "state" => "active",
    "username" => "jonsnow",
    "created_at" => "2023-07-17T20:07:20.055Z",
    "updated_at" => "2023-07-17T20:07:20.055Z"
  }

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

  def list_directories(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/directories"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "data" => [
          %{
            "id" => "directory_123",
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
        ],
        "list_metadata" => %{
          "before" => "before-id",
          "after" => "after-id"
        }
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def delete_directory(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      directory_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:directory_id)
      assert request.method == :delete
      assert request.url == "#{WorkOS.base_url()}/directories/#{directory_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      {status, body} = Keyword.get(opts, :respond_with, {204, %{}})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_user(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      directory_user_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:directory_user_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/directory_users/#{directory_user_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      {status, body} = Keyword.get(opts, :respond_with, {200, @directory_user_response})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def list_users(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/directory_users"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "data" => [
          @directory_user_response
        ],
        "list_metadata" => %{
          "before" => "before-id",
          "after" => "after-id"
        }
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_group(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      directory_group_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:directory_group_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/directory_groups/#{directory_group_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      # Refactor directory group response based on struct
      success_body = %{
        "id" => directory_group_id,
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

  def list_groups(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/directory_groups"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      # Refactor directory group response based on struct
      success_body = %{
        "data" => [
          %{
            "id" => "directory_123",
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
        ],
        "list_metadata" => %{
          "before" => "before-id",
          "after" => "after-id"
        }
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end
end

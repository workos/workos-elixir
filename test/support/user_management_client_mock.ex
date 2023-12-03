defmodule WorkOS.UserManagement.ClientMock do
  @moduledoc false

  use ExUnit.Case

  @user_mock %{
    "object" => "user",
    "id" => "user_01H5JQDV7R7ATEYZDEG0W5PRYS",
    "email" => "test@example.com",
    "first_name" => "Test 01",
    "last_name" => "User",
    "created_at" => "2023-07-18T02:07:19.911Z",
    "updated_at" => "2023-07-18T02:07:19.911Z",
    "email_verified" => true
  }

  @invitation_mock %{
    "object" => "invitation",
    "id" => "invitation_01H5JQDV7R7ATEYZDEG0W5PRYS",
    "email" => "test@workos.com",
    "state" => "pending",
    "accepted_at" => "2023-07-18T02:07:19.911Z",
    "revoked_at" => "2023-07-18T02:07:19.911Z",
    "expires_at" => "2023-07-18T02:07:19.911Z",
    "organization_id" => "org_01H5JQDV7R7ATEYZDEG0W5PRYS",
    "token" => "Z1uX3RbwcIl5fIGJJJCXXisdI",
    "created_at" => "2023-07-18T02:07:19.911Z",
    "updated_at" => "2023-07-18T02:07:19.911Z"
  }

  @organization_membership_mock %{
    "object" => "organization_membership",
    "id" => "om_01H5JQDV7R7ATEYZDEG0W5PRYS",
    "user_id" => "user_01H5JQDV7R7ATEYZDEG0W5PRYS",
    "organization_id" => "organization_01H5JQDV7R7ATEYZDEG0W5PRYS",
    "created_at" => "2023-07-18T02:07:19.911Z",
    "updated_at" => "2023-07-18T02:07:19.911Z"
  }

  def get_user(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      user_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:user_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/user_management/users/#{user_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = @user_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def list_users(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/user_management/users"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "data" => [
          @user_mock
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

  def create_user(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/user_management/users"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = @user_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def update_user(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      user_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:user_id)
      assert request.method == :put
      assert request.url == "#{WorkOS.base_url()}/user_management/users/#{user_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <- Keyword.get(opts, :assert_fields, []) |> Keyword.delete(:user_id) do
        assert body[to_string(field)] == value
      end

      success_body = @user_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def delete_user(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      user_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:user_id)
      assert request.method == :delete
      assert request.url == "#{WorkOS.base_url()}/user_management/users/#{user_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      {status, body} = Keyword.get(opts, :respond_with, {204, %{}})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def send_password_reset_email(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/user_management/password_reset/send"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        user: @user_mock
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def reset_password(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/user_management/password_reset/confirm"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "user" => @user_mock
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_organization_membership(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      organization_membership_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_membership_id)

      assert request.method == :get

      assert request.url ==
               "#{WorkOS.base_url()}/user_management/organization_memberships/#{organization_membership_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = @organization_membership_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def list_organization_memberships(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/user_management/organization_memberships"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "data" => [
          @organization_membership_mock
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

  def create_organization_membership(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/user_management/organization_memberships"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = @organization_membership_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def delete_organization_membership(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      organization_membership_id =
        opts |> Keyword.get(:assert_fields) |> Keyword.get(:organization_membership_id)

      assert request.method == :delete

      assert request.url ==
               "#{WorkOS.base_url()}/user_management/organization_memberships/#{organization_membership_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      {status, body} = Keyword.get(opts, :respond_with, {204, %{}})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def get_invitation(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      invitation_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:invitation_id)
      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/user_management/invitations/#{invitation_id}"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = @invitation_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def list_invitations(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :get
      assert request.url == "#{WorkOS.base_url()}/user_management/invitations"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = %{
        "data" => [
          @invitation_mock
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

  def send_invitation(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/user_management/invitations"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = @invitation_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end

  def revoke_invitation(context, opts \\ []) do
    Tesla.Mock.mock(fn request ->
      %{api_key: api_key} = context

      invitation_id = opts |> Keyword.get(:assert_fields) |> Keyword.get(:invitation_id)
      assert request.method == :post

      assert request.url ==
               "#{WorkOS.base_url()}/user_management/invitations/#{invitation_id}/revoke"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      success_body = @invitation_mock

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end)
  end
end

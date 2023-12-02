defmodule WorkOS.UserManagementTest do
  use WorkOS.TestCase

  alias WorkOS.UserManagement.ClientMock

  setup :setup_env

  describe "list_users" do
    test "without any options, returns users and metadata", context do
      context
      |> ClientMock.list_users()

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.User{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_users()
    end
  end

  describe "delete_user" do
    test "sends a request to delete a user", context do
      opts = [user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.delete_user(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.UserManagement.delete_user(opts |> Keyword.get(:user_id))
    end
  end

  describe "get_user" do
    test "requests a user", context do
      opts = [user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.get_user(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.User{id: id}} =
               WorkOS.UserManagement.get_user(opts |> Keyword.get(:user_id))

      refute is_nil(id)
    end
  end

  describe "create_user" do
    test "with a valid payload, creates a user", context do
      opts = [email: "test@example.com"]

      context |> ClientMock.create_user(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.User{id: id}} =
               WorkOS.UserManagement.create_user(opts |> Enum.into(%{}))

      refute is_nil(id)
    end
  end

  describe "update_user" do
    test "with a valid payload, updates a user", context do
      opts = [
        user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS",
        first_name: "Foo test",
        last_name: "Foo test"
      ]

      context |> ClientMock.update_user(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.User{id: id}} =
               WorkOS.UserManagement.update_user(
                 opts |> Keyword.get(:user_id),
                 opts |> Enum.into(%{})
               )

      refute is_nil(id)
    end
  end
end

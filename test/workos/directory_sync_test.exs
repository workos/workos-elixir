defmodule WorkOS.DirectorySyncTest do
  use WorkOS.TestCase

  alias WorkOS.DirectorySync.ClientMock

  setup :setup_env

  describe "get_directory" do
    test "requests a directory", context do
      opts = [directory_id: "directory_123"]

      context |> ClientMock.get_directory(assert_fields: opts)

      assert {:ok, %WorkOS.DirectorySync.Directory{id: id}} =
               WorkOS.DirectorySync.get_directory(opts |> Keyword.get(:directory_id))

      refute is_nil(id)
    end
  end

  describe "list_directories" do
    test "requests directories with options", context do
      opts = [organization_id: "org_1234"]

      context |> ClientMock.list_directories(assert_fields: opts)

      assert {:ok, %WorkOS.List{data: [%WorkOS.DirectorySync.Directory{}], list_metadata: %{}}} =
               WorkOS.DirectorySync.list_directories(opts |> Enum.into(%{}))
    end
  end

  describe "delete_directory" do
    test "sends a request to delete a directory", context do
      opts = [directory_id: "conn_123"]

      context |> ClientMock.delete_directory(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.DirectorySync.delete_directory(opts |> Keyword.get(:directory_id))
    end
  end

  describe "get_user" do
    test "requests a directory user", context do
      opts = [directory_user_id: "dir_usr_123"]

      context |> ClientMock.get_user(assert_fields: opts)

      assert {:ok, %WorkOS.DirectorySync.Directory.User{id: id}} =
               WorkOS.DirectorySync.get_user(opts |> Keyword.get(:directory_user_id))

      refute is_nil(id)
    end
  end

  describe "list_users" do
    test "requests directory users with options", context do
      opts = [directory: "directory_123"]

      context |> ClientMock.list_users(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.DirectorySync.Directory.User{custom_attributes: custom_attributes}],
                list_metadata: %{}
              }} = WorkOS.DirectorySync.list_users(opts |> Enum.into(%{}))

      assert %{"custom" => true} = custom_attributes
    end
  end

  describe "get_group" do
    test "requests a directory group", context do
      opts = [directory_group_id: "dir_grp_123"]

      context |> ClientMock.get_group(assert_fields: opts)

      assert {:ok, %WorkOS.DirectorySync.Directory.Group{id: id}} =
               WorkOS.DirectorySync.get_group(opts |> Keyword.get(:directory_group_id))

      refute is_nil(id)
    end
  end

  describe "list_groups" do
    test "requests directory groups with `directory` option", context do
      opts = [directory: "directory_123"]

      context |> ClientMock.list_groups(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.DirectorySync.Directory.Group{}],
                list_metadata: %{}
              }} = WorkOS.DirectorySync.list_groups(opts |> Enum.into(%{}))
    end

    test "requests directory groups with `user` option", context do
      opts = [user: "directory_usr_123"]

      context |> ClientMock.list_groups(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.DirectorySync.Directory.Group{}],
                list_metadata: %{}
              }} = WorkOS.DirectorySync.list_groups(opts |> Enum.into(%{}))
    end
  end
end

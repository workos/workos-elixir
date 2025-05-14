defmodule WorkOS.DirectorySyncTest do
  use WorkOS.TestCase

  alias WorkOS.DirectorySync.ClientMock

  setup :setup_env

  describe "get_directory" do
    test "requests a directory", context do
      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{
          status: 200,
          body: %{
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
        }
      end)

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

  describe "edge and error cases" do
    setup :setup_env

    # get_directory
    test "get_directory returns error on 404", context do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 404, body: %{}} end)
      opts = [directory_id: "bad_dir"]
      context |> ClientMock.get_directory(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.DirectorySync.get_directory(opts |> Keyword.get(:directory_id))
    end

    test "get_directory returns error on client error", context do
      Tesla.Mock.mock(fn _ -> {:error, :client_error} end)
      opts = [directory_id: "bad_dir"]
      context |> ClientMock.get_directory(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.DirectorySync.get_directory(opts |> Keyword.get(:directory_id))
    end

    test "get_directory/2 returns error on 404", context do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 404, body: %{}} end)
      opts = [directory_id: "bad_dir"]
      context |> ClientMock.get_directory(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.DirectorySync.get_directory(
                 WorkOS.client(),
                 opts |> Keyword.get(:directory_id)
               )
    end

    # list_directories
    test "list_directories returns error on 500", context do
      context |> ClientMock.list_directories(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.DirectorySync.list_directories(%{})
    end

    test "list_directories returns error on client error", context do
      context |> ClientMock.list_directories(respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.DirectorySync.list_directories(%{})
    end

    test "list_directories/2 returns error on 500", context do
      context |> ClientMock.list_directories(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.DirectorySync.list_directories(WorkOS.client(), %{})
    end

    # delete_directory
    test "delete_directory returns error on 404", context do
      opts = [directory_id: "bad_dir"]
      context |> ClientMock.delete_directory(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.DirectorySync.delete_directory(opts |> Keyword.get(:directory_id))
    end

    test "delete_directory returns error on client error", context do
      opts = [directory_id: "bad_dir"]

      context
      |> ClientMock.delete_directory(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.DirectorySync.delete_directory(opts |> Keyword.get(:directory_id))
    end

    test "delete_directory/2 returns error on 404", context do
      opts = [directory_id: "bad_dir"]
      context |> ClientMock.delete_directory(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.DirectorySync.delete_directory(
                 WorkOS.client(),
                 opts |> Keyword.get(:directory_id)
               )
    end

    # get_user
    test "get_user returns error on 404", context do
      opts = [directory_user_id: "bad_user"]
      context |> ClientMock.get_user(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.DirectorySync.get_user(opts |> Keyword.get(:directory_user_id))
    end

    test "get_user returns error on client error", context do
      opts = [directory_user_id: "bad_user"]
      context |> ClientMock.get_user(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.DirectorySync.get_user(opts |> Keyword.get(:directory_user_id))
    end

    test "get_user/2 returns error on 404", context do
      opts = [directory_user_id: "bad_user"]
      context |> ClientMock.get_user(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.DirectorySync.get_user(
                 WorkOS.client(),
                 opts |> Keyword.get(:directory_user_id)
               )
    end

    # list_users
    test "list_users returns error on 500", context do
      context |> ClientMock.list_users(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.DirectorySync.list_users(%{})
    end

    test "list_users returns error on client error", context do
      context |> ClientMock.list_users(respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.DirectorySync.list_users(%{})
    end

    test "list_users/2 returns error on 500", context do
      context |> ClientMock.list_users(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.DirectorySync.list_users(WorkOS.client(), %{})
    end

    # get_group
    test "get_group returns error on 404", context do
      opts = [directory_group_id: "bad_group"]
      context |> ClientMock.get_group(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.DirectorySync.get_group(opts |> Keyword.get(:directory_group_id))
    end

    test "get_group returns error on client error", context do
      opts = [directory_group_id: "bad_group"]
      context |> ClientMock.get_group(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.DirectorySync.get_group(opts |> Keyword.get(:directory_group_id))
    end

    test "get_group/2 returns error on 404", context do
      opts = [directory_group_id: "bad_group"]
      context |> ClientMock.get_group(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.DirectorySync.get_group(
                 WorkOS.client(),
                 opts |> Keyword.get(:directory_group_id)
               )
    end

    # list_groups
    test "list_groups returns error on 500", context do
      context |> ClientMock.list_groups(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.DirectorySync.list_groups(%{})
    end

    test "list_groups returns error on client error", context do
      context |> ClientMock.list_groups(respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.DirectorySync.list_groups(%{})
    end

    test "list_groups/2 returns error on 500", context do
      context |> ClientMock.list_groups(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.DirectorySync.list_groups(WorkOS.client(), %{})
    end
  end

  describe "struct creation and cast" do
    test "Directory struct creation and cast" do
      map = %{
        "id" => "directory_123",
        "object" => "directory",
        "name" => "Foo",
        "domain" => "foo-corp.com"
      }

      struct = WorkOS.DirectorySync.Directory.cast(map)

      assert %WorkOS.DirectorySync.Directory{
               id: "directory_123",
               object: "directory",
               name: "Foo",
               domain: "foo-corp.com"
             } = struct
    end

    test "Directory.User struct creation and cast" do
      map = %{
        "id" => "user_123",
        "object" => "directory_user",
        "first_name" => "Jon",
        "last_name" => "Snow"
      }

      struct = WorkOS.DirectorySync.Directory.User.cast(map)

      assert %WorkOS.DirectorySync.Directory.User{
               id: "user_123",
               object: "directory_user",
               first_name: "Jon",
               last_name: "Snow"
             } = struct
    end

    test "Directory.Group struct creation and cast" do
      map = %{"id" => "dir_grp_123", "object" => "directory_group", "name" => "Foo Group"}
      struct = WorkOS.DirectorySync.Directory.Group.cast(map)

      assert %WorkOS.DirectorySync.Directory.Group{
               id: "dir_grp_123",
               object: "directory_group",
               name: "Foo Group"
             } = struct
    end
  end

  describe "default argument coverage" do
    test "list_directories/0" do
      Tesla.Mock.mock(fn %{method: :get, url: url} ->
        assert url =~ "/directories"
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} =
               WorkOS.DirectorySync.list_directories()
    end

    test "list_users/0" do
      Tesla.Mock.mock(fn %{method: :get, url: url} ->
        assert url =~ "/directory_users"
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} = WorkOS.DirectorySync.list_users()
    end

    test "list_groups/0" do
      Tesla.Mock.mock(fn %{method: :get, url: url} ->
        assert url =~ "/directory_groups"
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} = WorkOS.DirectorySync.list_groups()
    end
  end
end

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
end

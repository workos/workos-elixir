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
end

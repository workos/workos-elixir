defmodule WorkOS.DirectorySyncTest do
  use ExUnit.Case
  doctest WorkOS.DirectorySync
  import Tesla.Mock

  alias WorkOS.DirectorySync

  describe "#delete_directory/1 with a valid directory id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/directories/directory_12345"} ->
          %Tesla.Env{status: 202, body: "Success"}
      end)

      :ok
    end

    test "returns a 202 status" do
      assert {:ok, "Success"} = WorkOS.DirectorySync.delete_directory('directory_12345')
    end
  end

  describe "#delete_directory/1 with an invalid directory id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/directories/invalid"} ->
          %Tesla.Env{status: 404, body: "Not Found"}
      end)

      :ok
    end

    test "returns a 404 status" do
      assert {:error, "Not Found"} = WorkOS.DirectorySync.delete_directory('invalid')
    end
  end
end

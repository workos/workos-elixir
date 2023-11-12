defmodule WorkOS.DirectorySync do
  @moduledoc """
  Manage Directory Sync in WorkOS.

  @see https://workos.com/docs/reference/directory-sync
  """

  alias WorkOS.DirectorySync.Directory

  @doc """
  Gets a directory given an ID.
  """
  @spec get_directory(String.t()) :: WorkOS.Client.response(Directory.t())
  @spec get_directory(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(Directory.t())
  def get_directory(client \\ WorkOS.client(), directory_id) do
    WorkOS.Client.get(client, Directory, "/directories/:id",
      opts: [
        path_params: [id: directory_id]
      ]
    )
  end
end

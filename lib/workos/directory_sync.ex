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

  @doc """
  Lists all directories.

  Parameter options:

    * `:domain` - The domain of a Directory.
    * `:organization_id` - Filter Directories by their associated organization.
    * `:search` - Searchable text to match against Directory names.
    * `:limit` - Maximum number of records to return. Accepts values between 1 and 100. Default is 10.
    * `:before` - An object ID that defines your place in the list. When the ID is not present, you are at the end of the list.
    * `:after` - Pagination cursor to receive records after a provided event ID.
    * `:order` - Order the results by the creation time. Supported values are "asc" and "desc" for showing older and newer records first respectively.

  """
  @spec list_directories(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(WorkOS.List.t(Directory.t()))
  def list_directories(client, opts) do
    WorkOS.Client.get(client, WorkOS.List.of(Directory), "/directories",
      opts: [
        query: %{
          domain: opts[:domain],
          organization_id: opts[:organization_id],
          search: opts[:search],
          limit: opts[:limit],
          before: opts[:before],
          after: opts[:after],
          order: opts[:order]
        }
      ]
    )
  end

  @spec list_directories(map()) ::
          WorkOS.Client.response(WorkOS.List.t(Directory.t()))
  def list_directories(opts \\ %{}) do
    WorkOS.Client.get(WorkOS.client(), WorkOS.List.of(Directory), "/directories",
      opts: [
        query: %{
          domain: opts[:domain],
          organization_id: opts[:organization_id],
          search: opts[:search],
          limit: opts[:limit],
          before: opts[:before],
          after: opts[:after],
          order: opts[:order]
        }
      ]
    )
  end
end

defmodule WorkOS.DirectorySync do
  import WorkOS.API

  @moduledoc """
  The Directory Sync module provides convenience methods for working with the
  WorkOS Directory Sync platform. You'll need a valid API key and to have
  created a Directory Sync connection on your WorkOS dashboard.

  @see https://docs.workos.com/directory-sync/overview
  """

  @doc """
  Retrieve directory groups.

  ### Parameters
  - params (map)
    - directory (string) the id of the directory to list groups for
    - user (string) the id of the user to list groups for
    - limit (number - optional) Upper limit on the number of objects to return, between 1 and 100. The default value is 10
    - before (string - optional) An object ID that defines your place in the list
    - after (string - optional) An object ID that defines your place in the list
    - order ("asc" or "desc" - optional) Supported values are "asc" and "desc" for ascending and descending order respectively

  ### Example
  WorkOS.DirectorySync.list_groups(%{directory: "directory_12345"})
  """
  def list_groups(params \\ %{}, opts \\ []) do
    query = process_params(params, [:directory, :user, :limit, :before, :after, :order])
    get("/directory_groups", query, opts)
  end

  @doc """
  Retrieve directory users.

  ### Parameters
  - params (map)
    - directory (string) the id of the directory to list users for
    - group (string) the id of the group to list users for
    - limit (number - optional) Upper limit on the number of objects to return, between 1 and 100. The default value is 10
    - before (string - optional) An object ID that defines your place in the list
    - after (string - optional) An object ID that defines your place in the list
    - order ("asc" or "desc" - optional) Supported values are "asc" and "desc" for ascending and descending order respectively

  ### Example
  WorkOS.DirectorySync.list_users(%{directory: "directory_12345"})
  """
  def list_users(params \\ %{}, opts \\ []) do
    query = process_params(params, [:directory, :group, :limit, :before, :after, :order])
    get("/directory_users", query, opts)
  end

  @doc """
  Retrieve directories.

  ### Parameters
  - params (map)
    - domain (string) the id of the domain to list directories for
    - search (string) the keyword to search directories for
    - limit (number - optional) Upper limit on the number of objects to return, between 1 and 100. The default value is 10
    - before (string - optional) An object ID that defines your place in the list
    - after (string - optional) An object ID that defines your place in the list
    - order ("asc" or "desc" - optional) Supported values are "asc" and "desc" for ascending and descending order respectively
    - organization_id (string) the id of the organization to list directories for

  ### Example
  WorkOS.DirectorySync.list_directories(%{domain: "workos.com"})
  """
  def list_directories(params \\ %{}, opts \\ []) do
    query =
      process_params(params, [:domain, :search, :limit, :before, :after, :order, :organization_id])

    get("/directories", query, opts)
  end

  @doc """
  Retrieve the directory group with the given ID.

  ### Parameters
  - user (string) the id of the user to retrieve

  ### Example
  WorkOS.DirectorySync.get_user("directory_user_12345")
  """
  def get_user(user, opts \\ []) do
    get("/directory_users/#{user}", %{}, opts)
  end

  @doc """
  Retrieve the directory group with the given ID.

  ### Parameters
  - group (string) the id of the group to retrieve

  ### Example
  WorkOS.DirectorySync.get_group("directory_group_12345")
  """
  def get_group(group, opts \\ []) do
    get("/directory_groups/#{group}", %{}, opts)
  end

  @doc """
  Retrieve the directory with the given ID.

  ### Parameters
  - directory (string) the id of the directory to retrieve

  ### Example
  WorkOS.DirectorySync.get_directory("directory_12345")
  """
  def get_directory(directory, opts \\ []) do
    get("/directories/#{directory}", %{}, opts)
  end

  @doc """
  Delete the directory with the given ID.

  ### Parameters
  - directory (string) the id of the directory to delete

  ### Example
  WorkOS.DirectorySync.delete_directory("directory_12345")
  """
  def delete_directory(directory, opts \\ []) do
    delete("/directories/#{directory}", %{}, opts)
  end
end

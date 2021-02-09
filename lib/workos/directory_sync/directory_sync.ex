defmodule WorkOS.DirectorySync do
  alias WorkOS.Api
  
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

  ### Example
  WorkOS.DirectorySync.list_groups(%{directory: "directory_12345"})
  """
  def list_groups(params, opts \\ [])
  def list_groups(params, opts) when is_map_key(params, :directory) or is_map_key(params, :user) do
    query = params
    |> Map.take([:directory, :user])
    Api.get("/directory_groups", query, opts)
  end
  def list_groups(_params, _opts), do: raise ArgumentError, message: "need either domain or user in params"

  @doc """
  Retrieve directory users.

  ### Parameters
  - params (map)
    - directory (string) the id of the directory to list users for
    - group (string) the id of the group to list users for

  ### Example
  WorkOS.DirectorySync.list_users(%{directory: "directory_12345"})
  """
  def list_users(params, opts \\ [])
  def list_users(params, opts) when is_map_key(params, :directory) or is_map_key(params, :group) do
    query = params
    |> Map.take([:directory, :user])
    Api.get("/directory_users", query, opts)
  end
  def list_users(_params, _opts), do: raise ArgumentError, message: "need either directory or group in params"

  @doc """
  Retrieve directories.

  ### Parameters
  - params (map)
    - domain (string) the id of the domain to list directories for
    - search (string) the keyword to search directories for

  ### Example
  WorkOS.DirectorySync.list_directories(%{domain: "workos.com"})
  """
  def list_directories(params, opts \\ [])
  def list_directories(params, opts) when is_map_key(params, :domain) or is_map_key(params, :search) do
    query = params
    |> Map.take([:domain, :search])
    Api.get("/directories", query, opts)
  end
  def list_directories(_params, _opts), do: raise ArgumentError, message: "need either domain or search in params"

  @doc """
  Retrieve the directory group with the given ID.

  ### Parameters
  - user (string) the id of the user to retrieve

  ### Example
  WorkOS.DirectorySync.get_user("directory_user_12345")
  """
  def get_user(user, opts \\ []) do
    Api.get("/directory_users/#{user}", %{}, opts)
  end

  @doc """
  Retrieve the directory group with the given ID.

  ### Parameters
  - group (string) the id of the group to retrieve

  ### Example
  WorkOS.DirectorySync.get_group("directory_group_12345")
  """
  def get_group(group, opts \\ []) do
    Api.get("/directory_groups/#{group}", %{}, opts)
  end
end

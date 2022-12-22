defmodule WorkOS.Organizations do
  import WorkOS.API

  @moduledoc """
  The Organizations module provides resource methods for working with Organizations
  """

  @doc """
  Create an organization

  ### Parameters
  - params (map)
    - name (string) A unique, descriptive name for the organization
    - allow_profiles_outside_organization (boolean - optional) Whether the Connections within this Organization should allow Profiles that do not have a domain that is set
    - domains (array of strings - optional) List of domains that belong to the organization

  ### Example
  WorkOS.Organizations.create_organization(%{
    domains: ["workos.com"],
    name: "WorkOS"
  })
  """
  def create_organization(params, opts \\ [])

  def create_organization(params, opts)
      when (is_map_key(params, :domains) or
              is_map_key(params, :allow_profiles_outside_organization)) and
             is_map_key(params, :name) do
    body = process_params(params, [:name, :domains, :allow_profiles_outside_organization])
    post("/organizations", body, opts)
  end

  def create_organization(_params, _opts),
    do:
      raise(ArgumentError,
        message: "need both domains (unless external profiles set to true) and name in params"
      )

  @doc """
  Delete an organization

  ### Parameters
  - organization_id (string) the id of the organization to delete

  ### Example
  WorkOS.Organizations.delete_organization("organization_12345")
  """
  def delete_organization(organization, opts \\ []) do
    delete("/organizations/#{organization}", %{}, opts)
  end

  @doc """
  Update an organization

  ### Parameters
  - organization (string) The ID of the organization to update
  - params (map)
    - name (string) Name of organization
    - allow_profiles_outside_organization (boolean - optional) Whether the Connections within this Organization should allow Profiles that do not have a domain that is set
    - domains (array of strings - optional) List of domains that belong to the organization

  ### Example
  WorkOS.Organizations.update_organization(organization="organization_12345", %{
    domains: ["workos.com"],
    name: "WorkOS"
  })
  """
  def update_organization(organization, params, opts \\ [])
      when (is_map_key(params, :domains) or
              is_map_key(params, :allow_profiles_outside_organization)) and
             is_map_key(params, :name) do
    body = process_params(params, [:name, :domains, :allow_profiles_outside_organization])
    put("/organizations/#{organization}", body, opts)
  end

  @doc """
  Get an organization

  ### Parameters
  - organization_id (string) the id of the organization to update

  ### Example
  WorkOS.Organizations.get_organization(organization="org_123")
  """
  def get_organization(organization, opts \\ []) do
    get("/organizations/#{organization}", %{}, opts)
  end

  @doc """
  List organizations

  ### Parameters
  - params (map)
    - domains (array of strings - optional) List of domains that belong to the organization
    - limit (number - optional) Upper limit on the number of objects to return, between 1 and 100. The default value is 10
    - before (string - optional) An object ID that defines your place in the list
    - after (string - optional) An object ID that defines your place in the list
    - order ("asc" or "desc" - optional) Supported values are "asc" and "desc" for ascending and descending order respectively

  ### Example
  WorkOS.Organizations.list_organizations()
  """
  def list_organizations(params \\ %{}, opts \\ []) do
    query = process_params(params, [:domains, :limit, :before, :after, :order])
    get("/organizations", query, opts)
  end
end

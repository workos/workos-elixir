defmodule WorkOS.Organizations do 
  import WorkOS.API 

  @moduledoc """
  The Organizations module provides resource methods for working with Organizations
  """

  @doc """
  Create an organization

  ### Parameters
  - params (map)
    - allow_profiles_outside_organization (boolean) Whether the Connections within this Organization should allow Profiles that do not have a domain that is set
    - domains (list of strings) List of domains that belong to the organization
    - name (string) A unique, descriptive name for the organization

  ### Example
  WorkOS.Portal.create_organization(%{
    domains: ["workos.com"],
    name: "WorkOS"
  })
  """
  def create_organization(params, opts \\ [])

  def create_organization(params, opts)
    when (is_map_key(params, :domains) or is_map_key(params, :allow_profiles_outside_organization)) and is_map_key(params, :name) do
      query = process_params(params, [:name, :domains, :allow_profiles_outside_organization])
      post("/organizations", query, opts)
  end

  def create_organization(_params, _opts),
    do: raise(ArgumentError, message: "need both domains(unless external profiles set to true) and name in params")

  @doc """
  Delete an organization

  ### Parameters
  - organization_id (string) the id of the organization to delete

  ### Example
  WorkOS.delete_organization("organization_12345")
  """
  def delete_organization(organization, opts \\ []) do
    delete("/organizations/#{organization}", %{}, opts)
  end

  @doc """
  Update an organization

  ### Parameters
  - organization_id (string) the id of the organization to update
  - name (string) name of the organization
  - allow_profiles_outside_organization (boolean - optional)
  - domains (array of strings - optional if allow_profiles_outside_organization is set to true)
  
  ### Example
  WorkOS.Portal.update_organization(organization="organization_12345")
  """
  def update_organization(organization, params, opts \\ [])
    when (is_map_key(params, :domains) or is_map_key(params, :allow_profiles_outside_organization)) and is_map_key(params, :name) do
      query = process_params(params, [:name, :domains, :allow_profiles_outside_organization])
      post("/organizations/#{organization}", query, opts)
  end

  @doc """
  Get an organization
  
  ### Parameters
  - organization_id (string) the id of the organization to update

  ### Example
  WorkOS.get_organization(organization="org_123")
  """
  def get_organization(organization, opts \\ []) do
    get("/organizations/#{organization}", %{}, opts)
  end

  @doc """
  List organizations

  ### Parameters
  - params (map)
    - domains (list of strings) List of domains that belong to the organization

  ### Example
  WorkOS.list_organizations(organization="org_123")
  """
  def list_organizations(params, opts \\ []) do
    query = process_params(params, [:domains])
    get("/organizations", %{}, opts)
  end
end

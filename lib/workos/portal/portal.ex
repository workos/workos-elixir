defmodule WorkOS.Portal do
  alias WorkOS.Api

  @moduledoc """
  The Portal module provides resource methods for working with the Admin
  Portal product

  @see https://workos.com/docs/admin-portal/guide
  """

  @doc """
  Create an organization

  ### Parameters
  - params (map)
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
      when is_map_key(params, :domains) and is_map_key(params, :name) do
    query = Api.process_params(params, [:domains, :name])
    Api.post("/organizations", query, opts)
  end

  def create_organization(_params, _opts),
    do: raise(ArgumentError, message: "need both domains and name in params")

  @doc """
  Delete an organization

  ### Parameters
   - organization_id (string) the id of the organization to delete

  ### Example
  WorkOS.Portal.delete_organization("organization_12345")
  """
  def delete_organization(organization, opts \\ []) do
    Api.delete("/organizations/#{organization}", %{}, opts)
  end

  @doc """
  Generate a link to grant access to an organization's Admin Portal

  ### Parameters
  - params (map)
    - intent (string) The access scope for the generated Admin Portal
     link. Valid values are: ["sso"]
    - organization (string) The ID of the organization the Admin
     Portal link will be generated for.
    - return_url (string) The URL that the end user will be redirected to upon
     exiting the generated Admin Portal. If none is provided, the default
     redirect link set in your WorkOS Dashboard will be used.

  ### Example
  WorkOS.Portal.generate_link(%{
    intent: "sso",
    organization: "org_1234"
  })
  """
  def generate_link(params, opts \\ [])

  def generate_link(params, opts) when is_map_key(params, :organization) do
    query = Api.process_params(params, [:intent, :organization, :return_url], %{intent: "sso"})
    Api.post("/portal/generate_link", query, opts)
  end

  def generate_link(_params, _opts),
    do: raise(ArgumentError, message: "need both intent and organization in params")

  @doc """
  Retrieve a list of organizations that have connections configured
  within your WorkOS dashboard.

  ### Parameters
  - params (map)
    - domains (array of strings) Filter organizations to only return those
     that are associated with the provided domains.
    - before (string) A pagination argument used to request
     organizations before the provided Organization ID.
    - after (string) A pagination argument used to request
     organizations after the provided Organization ID.
    - limit (integer) A pagination argument used to limit the number
      of listed Organizations that are returned.

  ### Example
  WorkOS.Portal.list_organizations()
  """
  def list_organizations(params \\ %{}, opts \\ []) do
    query = Api.process_params(params, [:domains, :limit, :before, :after])
    Api.get("/organizations", query, opts)
  end
end

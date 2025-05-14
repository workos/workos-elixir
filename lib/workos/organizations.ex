defmodule WorkOS.Organizations do
  @moduledoc """
  Manage Organizations in WorkOS.

  Provides functions to list, create, update, retrieve, and delete organizations via the WorkOS API.

  See the [WorkOS Organizations API Reference](https://workos.com/docs/reference/organization) for more details.

  ## Example Usage

  ```elixir
  # List organizations
  {:ok, %WorkOS.List{data: organizations}} = WorkOS.Organizations.list_organizations()

  # Create an organization
  {:ok, organization} = WorkOS.Organizations.create_organization(%{
    name: "Test Organization",
    domains: ["example.com"]
  })

  # Get an organization by ID
  {:ok, organization} = WorkOS.Organizations.get_organization("org_01EHT88Z8J8795GZNQ4ZP1J81T")

  # Update an organization
  {:ok, updated_org} = WorkOS.Organizations.update_organization(
    "org_01EHT88Z8J8795GZNQ4ZP1J81T",
    %{name: "New Name", domains: ["newdomain.com"]}
  )

  # Delete an organization
  {:ok, _} = WorkOS.Organizations.delete_organization("org_01EHT88Z8J8795GZNQ4ZP1J81T")
  ```
  """

  alias WorkOS.Empty
  alias WorkOS.Organizations.Organization

  @doc """
  Lists all organizations.

  Parameter options:

    * `:domains` - The domains of an Organization. Any Organization with a matching domain will be returned.
    * `:limit` - Maximum number of records to return. Accepts values between 1 and 100. Default is 10.
    * `:after` - Pagination cursor to receive records after a provided event ID.
    * `:before` - An object ID that defines your place in the list. When the ID is not present, you are at the end of the list.
    * `:order` - Order the results by the creation time. Supported values are "asc" and "desc" for showing older and newer records first respectively.

  """
  @spec list_organizations(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(WorkOS.List.t(Organization.t()))
  def list_organizations(client, opts) do
    WorkOS.Client.get(client, WorkOS.List.of(Organization), "/organizations",
      query: [
        domains: opts[:domains],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @spec list_organizations(map()) ::
          WorkOS.Client.response(WorkOS.List.t(Organization.t()))
  def list_organizations(opts \\ %{}) do
    WorkOS.Client.get(WorkOS.client(), WorkOS.List.of(Organization), "/organizations",
      query: [
        domains: opts[:domains],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @doc """
  Deletes an organization.
  """
  @spec delete_organization(String.t()) :: WorkOS.Client.response(nil)
  @spec delete_organization(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(nil)
  def delete_organization(client \\ WorkOS.client(), organization_id) do
    WorkOS.Client.delete(client, Empty, "/organizations/:id", %{},
      opts: [
        path_params: [id: organization_id]
      ]
    )
  end

  @doc """
  Gets an organization given an ID.
  """
  @spec get_organization(String.t()) :: WorkOS.Client.response(Organization.t())
  @spec get_organization(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(Organization.t())
  def get_organization(client \\ WorkOS.client(), organization_id) do
    WorkOS.Client.get(client, Organization, "/organizations/:id",
      opts: [
        path_params: [id: organization_id]
      ]
    )
  end

  @doc """
  Creates an organization.

  Parameter options:

    * `:name` - A descriptive name for the Organization. This field does not need to be unique. (required)
    * `:domains` - The domains of the Organization.
    * `:allow_profiles_outside_organization` - Whether the Connections within this Organization should allow Profiles that do not have a domain that is present in the set of the Organization's User Email Domains.
    * `:idempotency_key` - A unique string as the value. Each subsequent request matching this unique string will return the same response.

  """
  @spec create_organization(map()) :: WorkOS.Client.response(Organization.t())
  @spec create_organization(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Organization.t())
  def create_organization(client \\ WorkOS.client(), opts) when is_map_key(opts, :name) do
    WorkOS.Client.post(
      client,
      Organization,
      "/organizations",
      %{
        name: opts[:name],
        domains: opts[:domains],
        allow_profiles_outside_organization: opts[:allow_profiles_outside_organization]
      },
      headers: [
        {"Idempotency-Key", opts[:idempotency_key]}
      ]
    )
  end

  @doc """
  Updates an organization.

  Parameter options:

    * `:organization` - Unique identifier of the Organization. (required)
    * `:name` - A descriptive name for the Organization. This field does not need to be unique. (required)
    * `:domains` - The domains of the Organization.
    * `:allow_profiles_outside_organization` - Whether the Connections within this Organization should allow Profiles that do not have a domain that is present in the set of the Organization's User Email Domains.

  """
  @spec update_organization(String.t(), map()) :: WorkOS.Client.response(Organization.t())
  @spec update_organization(WorkOS.Client.t(), String.t(), map()) ::
          WorkOS.Client.response(Organization.t())
  def update_organization(client \\ WorkOS.client(), organization_id, opts)
      when is_map_key(opts, :name) do
    WorkOS.Client.put(client, Organization, "/organizations/#{organization_id}", %{
      name: opts[:name],
      domains: opts[:domains],
      allow_profiles_outside_organization: !!opts[:allow_profiles_outside_organization]
    })
  end
end

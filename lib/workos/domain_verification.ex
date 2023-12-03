defmodule WorkOS.DomainVerification do
  @moduledoc """
  Manage Domain Verification in WorkOS.

  @see https://workos.com/docs/reference/domain-verification
  """

  alias WorkOS.DomainVerification.OrganizationDomain

  @doc """
  Gets an organization domain given an ID.
  """
  @spec get_organization_domain(String.t()) :: WorkOS.Client.response(OrganizationDomain.t())
  @spec get_organization_domain(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(OrganizationDomain.t())
  def get_organization_domain(client \\ WorkOS.client(), organization_domain_id) do
    WorkOS.Client.get(client, OrganizationDomain, "/organization_domains/:id",
      opts: [
        path_params: [id: organization_domain_id]
      ]
    )
  end

  @doc """
  Creates an organization domain.

  Parameter options:

    * `:organization_id` - ID of the parent Organization. (required)
    * `:domain` - Domain for the Organization Domain. (required)

  """
  @spec create_organization_domain(map()) :: WorkOS.Client.response(OrganizationDomain.t())
  @spec create_organization_domain(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(OrganizationDomain.t())
  def create_organization_domain(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :organization_id) and is_map_key(opts, :domain) do
    WorkOS.Client.post(
      client,
      OrganizationDomain,
      "/organization_domains",
      %{
        organization_id: opts[:organization_id],
        domain: opts[:domain]
      }
    )
  end

  @doc """
  Verifies an organization domain
  """
  @spec verify_organization_domain(String.t()) :: WorkOS.Client.response(OrganizationDomain.t())
  @spec verify_organization_domain(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(OrganizationDomain.t())
  def verify_organization_domain(client \\ WorkOS.client(), organization_domain_id) do
    WorkOS.Client.post(client, OrganizationDomain, "/organization_domains/:id", %{},
      opts: [
        path_params: [id: organization_domain_id]
      ]
    )
  end
end

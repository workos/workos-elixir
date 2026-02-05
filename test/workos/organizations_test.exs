defmodule WorkOS.OrganizationsTest do
  use WorkOS.TestCase

  alias WorkOS.Organizations.ClientMock

  setup :setup_env

  describe "list_organizations" do
    test "without any options, returns organizations and metadata", context do
      context
      |> ClientMock.list_organizations()

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.Organizations.Organization{}, %WorkOS.Organizations.Organization{}],
                list_metadata: %{}
              }} = WorkOS.Organizations.list_organizations()
    end

    test "with the domain option, forms the proper request to the API", context do
      opts = [domains: ["example.com"]]

      context
      |> ClientMock.list_organizations(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.Organizations.Organization{}, %WorkOS.Organizations.Organization{}],
                list_metadata: %{}
              }} = WorkOS.Organizations.list_organizations(opts |> Enum.into(%{}))
    end
  end

  describe "delete_organization" do
    test "sends a request to delete an organization", context do
      opts = [organization_id: "org_01EHT88Z8J8795GZNQ4ZP1J81T"]

      context |> ClientMock.delete_organization(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.Organizations.delete_organization(opts |> Keyword.get(:organization_id))
    end
  end

  describe "get_organization" do
    test "requests an organization", context do
      opts = [organization_id: "org_01EHT88Z8J8795GZNQ4ZP1J81T"]

      context |> ClientMock.get_organization(assert_fields: opts)

      assert {:ok, %WorkOS.Organizations.Organization{id: id}} =
               WorkOS.Organizations.get_organization(opts |> Keyword.get(:organization_id))

      refute is_nil(id)
    end
  end

  describe "get_organization_by_external_id" do
    test "requests an organization by external_id", context do
      opts = [external_id: "ext_org_123"]
      context |> ClientMock.get_organization_by_external_id(assert_fields: opts)

      assert {:ok, %WorkOS.Organizations.Organization{id: id, external_id: external_id}} =
               WorkOS.Organizations.get_organization_by_external_id(opts |> Keyword.get(:external_id))

      refute is_nil(id)
      assert external_id == "ext_org_123"
    end
  end

  describe "create_organization" do
    test "with an idempotency key, includes an idempotency key with request", context do
      opts = [
        domain_data: [%{"domain" => "example.com", "state" => "pending"}],
        name: "Test Organization",
        idempotency_key: "the-idempotency-key"
      ]

      context |> ClientMock.create_organization(assert_fields: opts)

      assert {:ok, %WorkOS.Organizations.Organization{id: id}} =
               WorkOS.Organizations.create_organization(opts |> Enum.into(%{}))

      refute is_nil(id)
    end

    test "with a valid payload, creates an organization", context do
      opts = [
        domain_data: [%{"domain" => "example.com", "state" => "pending"}],
        name: "Test Organization"
      ]

      context |> ClientMock.create_organization(assert_fields: opts)

      assert {:ok, %WorkOS.Organizations.Organization{id: id}} =
               WorkOS.Organizations.create_organization(opts |> Enum.into(%{}))

      refute is_nil(id)
    end
  end

  describe "update_organization" do
    test "with a valid payload, updates an organization", context do
      opts = [
        organization_id: "org_01EHT88Z8J8795GZNQ4ZP1J81T",
        domain_data: [%{"domain" => "example.com", "state" => "pending"}],
        name: "Test Organization 2"
      ]

      context |> ClientMock.update_organization(assert_fields: opts)

      assert {:ok, %WorkOS.Organizations.Organization{id: id}} =
               WorkOS.Organizations.update_organization(
                 opts |> Keyword.get(:organization_id),
                 opts |> Enum.into(%{})
               )

      refute is_nil(id)
    end
  end
end

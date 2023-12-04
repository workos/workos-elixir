defmodule WorkOS.DomainVerificationTest do
  use WorkOS.TestCase

  alias WorkOS.DomainVerification.ClientMock

  setup :setup_env

  describe "get_organization_domain" do
    test "requests an organization domain", context do
      opts = [organization_domain_id: "org_domain_01HCZRAP3TPQ0X0DKJHR32TATG"]

      context |> ClientMock.get_organization_domain(assert_fields: opts)

      assert {:ok, %WorkOS.DomainVerification.OrganizationDomain{id: id}} =
               WorkOS.DomainVerification.get_organization_domain(
                 opts
                 |> Keyword.get(:organization_domain_id)
               )

      refute is_nil(id)
    end
  end

  describe "create_organization_domain" do
    test "with a valid payload, creates an organization domain", context do
      opts = [organization_id: "org_01HCZRAP3TPQ0X0DKJHR32TATG", domain: "workos.com"]

      context |> ClientMock.create_organization_domain(assert_fields: opts)

      assert {:ok, %WorkOS.DomainVerification.OrganizationDomain{id: id}} =
               WorkOS.DomainVerification.create_organization_domain(opts |> Enum.into(%{}))

      refute is_nil(id)
    end
  end

  describe "verify_organization_domain" do
    test "verifies an organization domain", context do
      opts = [organization_domain_id: "org_domain_01HCZRAP3TPQ0X0DKJHR32TATG"]

      context |> ClientMock.verify_organization_domain(assert_fields: opts)

      assert {:ok, %WorkOS.DomainVerification.OrganizationDomain{id: id}} =
               WorkOS.DomainVerification.verify_organization_domain(
                 opts
                 |> Keyword.get(:organization_domain_id)
               )

      refute is_nil(id)
    end
  end
end

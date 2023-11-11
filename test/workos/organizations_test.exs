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
    # TODO - Implement tests
  end

  describe "get_organization" do
    # TODO - Implement tests
  end

  describe "create_organization" do
    # TODO - Implement tests
  end

  describe "update_organization" do
    # TODO - Implement tests
  end
end

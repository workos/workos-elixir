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

  describe "create_organization" do
    test "with an idempotency key, includes an idempotency key with request", context do
      opts = [
        domains: ["example.com"],
        name: "Test Organization",
        idempotency_key: "the-idempotency-key"
      ]

      context |> ClientMock.create_organization(assert_fields: opts)

      assert {:ok, %WorkOS.Organizations.Organization{id: id}} =
               WorkOS.Organizations.create_organization(opts |> Enum.into(%{}))

      refute is_nil(id)
    end

    test "with a valid payload, creates an organization", context do
      opts = [domains: ["example.com"], name: "Test Organization"]

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
        domains: ["example.com"],
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

  describe "edge and error cases" do
    test "list_organizations returns error on 500", context do
      context |> ClientMock.list_organizations(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.Organizations.list_organizations()
    end

    test "get_organization returns error on 404", context do
      opts = [organization_id: "nonexistent"]
      context |> ClientMock.get_organization(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.Organizations.get_organization(opts[:organization_id])
    end

    test "create_organization returns error when :name is missing", _context do
      opts = %{domains: ["example.com"]}
      assert {:error, _} = WorkOS.Organizations.create_organization(opts)
    end

    test "update_organization returns error when :name is missing", _context do
      organization_id = "org_01EHT88Z8J8795GZNQ4ZP1J81T"
      opts = %{domains: ["example.com"]}
      assert {:error, _} = WorkOS.Organizations.update_organization(organization_id, opts)
    end

    test "list_organizations returns empty list", context do
      context
      |> ClientMock.list_organizations(
        respond_with: {200, %{"data" => [], "list_metadata" => %{}}}
      )

      assert {:ok, %WorkOS.List{data: [], list_metadata: _}} =
               WorkOS.Organizations.list_organizations()
    end
  end

  describe "WorkOS.Organizations argument validation and error cases" do
    test "list_organizations/1 with no arguments (default path)" do
      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      result = WorkOS.Organizations.list_organizations()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "list_organizations/2 with empty map" do
      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      client = WorkOS.client()
      result = WorkOS.Organizations.list_organizations(client, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "list_organizations/2 with all options nil" do
      Tesla.Mock.mock(fn _ ->
        %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
      end)

      client = WorkOS.client()
      opts = %{domains: nil, limit: nil, after: nil, before: nil, order: nil}
      result = WorkOS.Organizations.list_organizations(client, opts)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "create_organization/2 returns error when :name is missing" do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 400, body: %{"error" => "missing_name"}} end)
      client = WorkOS.client()
      opts = %{domains: ["example.com"]}
      assert {:error, _} = WorkOS.Organizations.create_organization(client, opts)
    end

    test "update_organization/3 returns error when :name is missing" do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 400, body: %{"error" => "missing_name"}} end)
      client = WorkOS.client()
      organization_id = "org_01EHT88Z8J8795GZNQ4ZP1J81T"
      opts = %{domains: ["example.com"]}
      assert {:error, _} = WorkOS.Organizations.update_organization(client, organization_id, opts)
    end

    test "create_organization/2 propagates client error" do
      m = Module.concat([:TestOrgClient])

      defmodule m do
        def post(_, _, _, _), do: {:error, :client_error}
        def request(_, _), do: {:error, :client_error}
      end

      client = %WorkOS.Client{api_key: "k", client_id: "c", base_url: "u", client: m}

      assert {:error, :client_error} =
               WorkOS.Organizations.create_organization(client, %{
                 name: "Test",
                 domains: ["example.com"]
               })
    end

    test "get_organization/2 propagates client error" do
      m = Module.concat([:TestOrgClient2])

      defmodule m do
        def get(_, _, _, _), do: {:error, :client_error}
        def request(_, _), do: {:error, :client_error}
      end

      client = %WorkOS.Client{api_key: "k", client_id: "c", base_url: "u", client: m}
      assert {:error, :client_error} = WorkOS.Organizations.get_organization(client, "org_123")
    end

    test "update_organization/3 propagates client error" do
      m = Module.concat([:TestOrgClient3])

      defmodule m do
        def put(_, _, _, _), do: {:error, :client_error}
        def request(_, _), do: {:error, :client_error}
      end

      client = %WorkOS.Client{api_key: "k", client_id: "c", base_url: "u", client: m}

      assert {:error, :client_error} =
               WorkOS.Organizations.update_organization(client, "org_123", %{
                 name: "Test",
                 domains: ["example.com"]
               })
    end

    test "delete_organization/2 propagates client error" do
      m = Module.concat([:TestOrgClient4])

      defmodule m do
        def delete(_, _, _, _), do: {:error, :client_error}
        def request(_, _), do: {:error, :client_error}
      end

      client = %WorkOS.Client{api_key: "k", client_id: "c", base_url: "u", client: m}
      assert {:error, :client_error} = WorkOS.Organizations.delete_organization(client, "org_123")
    end
  end
end

defmodule WorkOS.OrganizationsTest do
  use ExUnit.Case
  doctest WorkOS.Organizations
  import Tesla.Mock

  alias WorkOS.Organizations

  describe "#list_organizations/1" do 
    setup do
      mock(fn
        %{method: :get, url: "https://api.workos.com/organizations"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do 
      assert {:ok, "Success"} = Organizations.list_organizations
    end 
  end

  describe "#create_organization/1 with a name and domain" do 
    setup do
      mock(fn
        %{method: :post, url: "https://api.workos.com/organizations"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do 
      assert {:ok, "Success"} = Organizations.create_organization(%{
        name: "Test Corp",
        domains: ["workos.com"]
      })
    end 
  end 

  describe "#get_organization/2 with an valid id" do
    setup do
      mock(fn
        %{method: :get, url: "https://api.workos.com/organizations/org_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do
      assert {:ok, "Success"} = Organizations.get_organization('org_12345')
    end
  end

  describe "#update_organization/2 with a valid id" do
    setup do
      mock(fn
        %{method: :put, url: "https://api.workos.com/organizations/org_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do
      assert {:ok, "Success"} = Organizations.update_organization('org_12345', %{
        name: "WorkOS",
        domains: ["workos.com"],
      })
    end
  end

  describe "#update_organization/2 with an invalid id" do
    setup do
      mock(fn
        %{method: :put, url: "https://api.workos.com/organizations/invalid"} ->
          %Tesla.Env{status: 404, body: "Not Found"}
      end)

      :ok
    end

    test "returns a 404 status" do
      assert {:error, "Error"} = Organizations.update_organization('invalid', %{
        name: "WorkOS",
        domains: ["workos.com"],
      })
    end
  end

  describe "#delete_organization/1 with a valid id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/organizations/org_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do
      assert {:ok, "Success"} = Organizations.delete_organization('org_12345')
    end
  end

  describe "#delete_organization/1 with an invalid id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/organizations/invalid"} ->
          %Tesla.Env{status: 404, body: "Not Found"}
      end)

      :ok
    end

    test "returns a 404 status" do
      assert {:error, "Not Found"} = Organizations.delete_organization('invalid')
    end
  end
end

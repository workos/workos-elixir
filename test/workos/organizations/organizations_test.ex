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
      ## TODO
    end 
  end

  describe "#create_organization/2" do 
    setup do
      mock(fn
        %{method: :post, url: "https://api.workos.com/organizations"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do 
      ## TODO
    end 
  end 

  describe "#get_organization/2 with an id" do
    setup do
      mock(fn
        %{method: :get, url: "https://api.workos.com/organizations/org_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 200 status" do
      assert {:ok, "Success"} = WorkOS.Organizations.get_organization('org_12345')
    end
  end

  describe "#update_organization/1 with a valid directory id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/organizations/org_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 202 status" do
      assert {:ok, "Success"} = WorkOS.Organizations.delete_organization('org_12345')
    end
  end

  describe "#delete_organization/1 with a valid directory id" do
    setup do
      mock(fn
        %{method: :delete, url: "https://api.workos.com/organizations/org_12345"} ->
          %Tesla.Env{status: 200, body: "Success"}
      end)

      :ok
    end

    test "returns a 202 status" do
      assert {:ok, "Success"} = WorkOS.Organizations.delete_organization('org_12345')
    end
  end
end

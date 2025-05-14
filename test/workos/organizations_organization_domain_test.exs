defmodule WorkOS.Organizations.Organization.DomainTest do
  use ExUnit.Case, async: true

  alias WorkOS.Organizations.Organization.Domain

  describe "struct creation" do
    test "creates a struct with required fields" do
      domain = %Domain{id: "id_123", object: "organization_domain", domain: "example.com"}
      assert domain.id == "id_123"
      assert domain.object == "organization_domain"
      assert domain.domain == "example.com"
    end
  end

  describe "cast/1" do
    test "casts a map to a Domain struct" do
      map = %{"id" => "id_123", "object" => "organization_domain", "domain" => "example.com"}
      domain = Domain.cast(map)
      assert %Domain{id: "id_123", object: "organization_domain", domain: "example.com"} = domain
    end
  end
end

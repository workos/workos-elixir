defmodule WorkOSTest do
  use ExUnit.Case
  doctest WorkOS

  describe "#host/1" do
    test "returns the configured host value" do
      assert WorkOS.host() == "api.workos.com"
    end
  end

  describe "#base_url/1" do
    test "returns the configured base_url value" do
      assert WorkOS.base_url() == "https://api.workos.com"
    end
  end

  describe "#api_key/1" do
    test "returns the configured api_key value by default" do
      assert WorkOS.api_key() == "sk_TEST"
    end

    test "overrides the configured api_key value with a value from opts" do
      assert WorkOS.api_key(api_key: "sk_OTHER") == "sk_OTHER"
    end
  end

  describe "#client_id/1" do
    test "returns the configured client_id value by default" do
      assert WorkOS.client_id() == "project_TEST"
    end

    test "overrides the configured client_id value with a value from opts" do
      assert WorkOS.client_id(client_id: "project_OTHER") == "project_OTHER"
    end
  end
end

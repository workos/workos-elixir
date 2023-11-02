defmodule WorkOS.SSOTest do
  use WorkOS.TestCase

  alias WorkOS.ClientMock

  describe "get_authorization_url" do
    test "generates an authorize url with the default api hostname" do
      opts = [connection: "mock-connection-id", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, _success_url} = WorkOS.SSO.get_authorization_url(Map.new(opts))
    end

    test "with no domain or provider, throws an error for incomplete arguments" do
    end

    test "generates an authorize url with a given provider" do
    end

    test "generates an authorize url with a given connection" do
    end

    test "generates an authorization URL with a given organization" do
    end

    test "generates an authorize url with a given custom api hostname" do
    end

    test "generates an authorize url with a given state" do
    end

    test "generates an authorize url with a given domain hint" do
    end

    test "generates an authorize url with a given login hint" do
    end
  end

  describe "get_profile_and_token" do
    test "with all information provided, sends a request to the WorkOS API for a profile" do
    end

    test "without a groups attribute, sends a request to the WorkOS API for a profile" do
    end
  end

  describe "get_profile" do
    test "calls the `/sso/profile` endpoint with the provided access token" do
    end
  end

  describe "get_connection" do
    test "requests a connection" do
    end
  end

  describe "list_connection" do
    test "requests a list of connections" do
    end
  end

  describe "delete_connection" do
    test "sends a request to delete a connection" do
    end
  end
end

defmodule WorkOS.SSOTest do
  use WorkOS.TestCase

  alias WorkOS.ClientMock

  describe "get_authorization_url" do
    test "with no custom api hostname, generates an authorize url with the default api hostname" do

    end

    test "with no domain or provider, throws an error for incomplete arguments" do

    end

    test "with a provider, generates an authorize url with the provider" do

    end

    test "with a connection, generates an authorize url with the connection" do

    end

    test "with a organization, generates an authorization URL with the organization generates an authorization URL with the organization" do

    end

    test "with a custom api hostname, generates an authorize url with the custom api hostname" do

    end

    test "with state, generates an authorize url with the provided state" do

    end

    test "with domain hint, generates an authorize url with the provided domain hint" do

    end

    test "with login hint, generates an authorize url with the provided login hint" do

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

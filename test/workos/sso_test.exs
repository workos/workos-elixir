defmodule WorkOS.SSOTest do
  use WorkOS.TestCase

  def parse_uri(url) do
    uri = URI.parse(url)
    %URI{uri | query: URI.query_decoder(uri.query) |> Enum.to_list()}
  end

  describe "get_authorization_url" do
    test "generates an authorize url with the default `base_url`" do
      opts = [connection: "mock-connection-id", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert WorkOS.base_url() =~ parse_uri(success_url).host
    end

    test "with no `domain` or `provider`, returns error for incomplete arguments" do
      opts = [redirect_uri: "example.com/sso/workos/callback"]

      assert {:error, _error_message} = WorkOS.SSO.get_authorization_url(opts |> Map.new())
    end

    test "generates an authorize url with a `provider`" do
      opts = [provider: "MicrosoftOAuth", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert {"provider", "MicrosoftOAuth"} in parse_uri(success_url).query
    end

    test "generates an authorize url with a `connection`" do
      opts = [connection: "mock-connection-id", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert {"connection", "mock-connection-id"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a `organization`" do
      opts = [organization: "mock-organization", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert {"organization", "mock-organization"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a custom `base_url` from app config" do
      Application.put_env(:workos, WorkOS.Client,
        base_url: "https://base-url.com",
        api_key: "sk_mock-api-key",
        client_id: "project_client-id-mock"
      )

      opts = [provider: "GoogleOAuth"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert "base-url.com" == parse_uri(success_url).host

      Application.delete_env(:workos, :base_url)
    end

    test "generates an authorize url with a `state`" do
      opts = [provider: "GoogleOAuth", state: "mock-state"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert {"state", "mock-state"} in parse_uri(success_url).query
    end

    test "generates an authorize url with a given `domain_hint`" do
      opts = [organization: "mock-organization", domain_hint: "mock-domain-hint"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert {"domain_hint", "mock-domain-hint"} in parse_uri(success_url).query
    end

    test "generates an authorize url with a given `login_hint`" do
      opts = [organization: "mock-organization", login_hint: "mock-login-hint"]

      assert {:ok, success_url} = WorkOS.SSO.get_authorization_url(opts |> Map.new())

      assert {"login_hint", "mock-login-hint"} in parse_uri(success_url).query
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

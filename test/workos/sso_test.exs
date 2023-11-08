defmodule WorkOS.SSOTest do
  use WorkOS.TestCase

  alias WorkOS.ClientMock

  setup :setup_env

  def parse_uri(url) do
    uri = URI.parse(url)
    %URI{uri | query: URI.query_decoder(uri.query) |> Enum.to_list()}
  end

  describe "get_authorization_url" do
    test "generates an authorize url with the default `base_url`" do
      opts = [connection: "mock-connection-id", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert WorkOS.base_url() =~ parse_uri(success_url).host
    end

    test "with no `domain` or `provider`, returns error for incomplete arguments" do
      opts = [redirect_uri: "example.com/sso/workos/callback"]

      assert {:error, _error_message} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()
    end

    test "generates an authorize url with a `provider`" do
      opts = [provider: "MicrosoftOAuth", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"provider", "MicrosoftOAuth"} in parse_uri(success_url).query
    end

    test "generates an authorize url with a `connection`" do
      opts = [connection: "mock-connection-id", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"connection", "mock-connection-id"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a `organization`" do
      opts = [organization: "mock-organization", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"organization", "mock-organization"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a custom `base_url` from app config" do
      initial_config = Application.get_env(:workos, WorkOS.Client)

      Application.put_env(
        :workos,
        WorkOS.Client,
        Keyword.put(initial_config, :base_url, "https://custom-base-url.com")
      )

      opts = [provider: "GoogleOAuth"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert "custom-base-url.com" == parse_uri(success_url).host

      Application.put_env(:workos, WorkOS.Client, initial_config)
    end

    test "generates an authorization url with a `state`" do
      opts = [provider: "GoogleOAuth", state: "mock-state"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"state", "mock-state"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a given `domain_hint`" do
      opts = [organization: "mock-organization", domain_hint: "mock-domain-hint"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"domain_hint", "mock-domain-hint"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a given `login_hint`" do
      opts = [organization: "mock-organization", login_hint: "mock-login-hint"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"login_hint", "mock-login-hint"} in parse_uri(success_url).query
    end
  end

  describe "get_profile_and_token" do
    test "with all information provided, sends a request to the WorkOS API for a profile",
         context do
      opts = [code: "authorization_code"]

      context |> ClientMock.get_profile_and_token(assert_fields: opts)

      assert {:ok, %WorkOS.SSO.ProfileAndToken{access_token: access_token, profile: profile}} =
               WorkOS.SSO.get_profile_and_token(Map.new(opts))

      refute is_nil(access_token)
      refute is_nil(profile)
    end

    test "without a groups attribute, sends a request to the WorkOS API for a profile", context do
      opts = [code: "authorization_code"]

      context
      |> Map.put(:with_group_attribute, false)
      |> ClientMock.get_profile_and_token(assert_fields: opts)

      {:ok, %WorkOS.SSO.ProfileAndToken{access_token: access_token, profile: profile}} =
        WorkOS.SSO.get_profile_and_token(Map.new(opts))

      refute is_nil(access_token)
      refute is_nil(profile)
    end
  end

  describe "get_profile" do
    test "calls the `/sso/profile` endpoint with the provided access token", context do
      opts = [access_token: "access_token"]

      context |> ClientMock.get_profile(assert_fields: opts)

      assert {:ok, %WorkOS.SSO.Profile{id: id}} =
               WorkOS.SSO.get_profile(opts |> Keyword.get(:access_token))

      refute is_nil(id)
    end
  end

  describe "get_connection" do
    test "requests a connection", context do
      opts = [connection_id: "conn_123"]

      context |> ClientMock.get_connection(assert_fields: opts)

      assert {:ok, %WorkOS.SSO.Connection{id: id}} =
               WorkOS.SSO.get_connection(opts |> Keyword.get(:connection_id))

      refute is_nil(id)
    end
  end

  @tag :single
  describe "list_connections" do
    test "requests a list of connections", context do
      opts = [organization_id: "org_1234"]

      context |> ClientMock.list_connections(assert_fields: opts)

      assert {:ok, %WorkOS.List{data: [%WorkOS.SSO.Connection{}], list_metadata: %{}}} =
               WorkOS.SSO.list_connections(opts |> Enum.into(%{}))
    end
  end

  describe "delete_connection" do
    test "sends a request to delete a connection" do
    end
  end
end

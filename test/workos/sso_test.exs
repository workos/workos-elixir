defmodule WorkOS.SSOTest do
  use WorkOS.TestCase

  alias WorkOS.SSO.ClientMock

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

    test "with no `domain`, `provider`, `connection` or `organization`, returns error for incomplete arguments" do
      opts = [redirect_uri: "example.com/sso/workos/callback"]

      assert {:error, _error_message} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()
    end

    test "with no `redirect_uri`, returns error for incomplete arguments" do
      opts = [provider: "GoogleOAuth"]

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

      opts = [provider: "GoogleOAuth", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert "custom-base-url.com" == parse_uri(success_url).host

      Application.put_env(:workos, WorkOS.Client, initial_config)
    end

    test "generates an authorization url with a `state`" do
      opts = [
        provider: "GoogleOAuth",
        state: "mock-state",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"state", "mock-state"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a given `domain_hint`" do
      opts = [
        organization: "mock-organization",
        domain_hint: "mock-domain-hint",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"domain_hint", "mock-domain-hint"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a given `login_hint`" do
      opts = [
        organization: "mock-organization",
        login_hint: "mock-login-hint",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} = opts |> Map.new() |> WorkOS.SSO.get_authorization_url()

      assert {"login_hint", "mock-login-hint"} in parse_uri(success_url).query
    end

    test "with a invalid selector, returns error" do
      opts = [
        redirect_uri: "example.com/sso/workos/callback"
      ]

      {:error, _message} = opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()
    end

    test "raises if client_id is missing in params and config" do
      opts = [connection: "mock-connection-id", redirect_uri: "example.com/sso/workos/callback"]
      # Backup and clear the client_id from the WorkOS.Client config
      initial_config = Application.get_env(:workos, WorkOS.Client)
      cleaned_config = Keyword.delete(initial_config || [], :client_id)
      Application.put_env(:workos, WorkOS.Client, cleaned_config)
      initial_env_client_id = System.get_env("WORKOS_CLIENT_ID")
      System.delete_env("WORKOS_CLIENT_ID")

      on_exit(fn ->
        # Restore the client_id config and env var
        if initial_config do
          Application.put_env(:workos, WorkOS.Client, initial_config)
        else
          Application.delete_env(:workos, WorkOS.Client)
        end

        if initial_env_client_id do
          System.put_env("WORKOS_CLIENT_ID", initial_env_client_id)
        end
      end)

      assert_raise RuntimeError, ~r/Missing required `client_id` parameter./, fn ->
        opts |> Map.new() |> WorkOS.SSO.get_authorization_url()
      end
    end
  end

  describe "get_profile_and_token" do
    test "with all information provided, sends a request to the WorkOS API for a profile",
         context do
      opts = [code: "authorization_code"]

      context |> ClientMock.get_profile_and_token(assert_fields: opts)

      assert {:ok, %WorkOS.SSO.ProfileAndToken{access_token: access_token, profile: profile}} =
               WorkOS.SSO.get_profile_and_token(opts |> Keyword.get(:code))

      refute is_nil(access_token)
      refute is_nil(profile)
    end

    test "without a groups attribute, sends a request to the WorkOS API for a profile", context do
      opts = [code: "authorization_code"]

      context
      |> Map.put(:with_group_attribute, false)
      |> ClientMock.get_profile_and_token(assert_fields: opts)

      {:ok, %WorkOS.SSO.ProfileAndToken{access_token: access_token, profile: profile}} =
        WorkOS.SSO.get_profile_and_token(opts |> Keyword.get(:code))

      refute is_nil(access_token)
      refute is_nil(profile)
    end

    test "get_profile_and_token returns error on 400", context do
      opts = [code: "bad_code"]

      context
      |> ClientMock.get_profile_and_token(
        assert_fields: opts,
        respond_with: {400, %{"error" => "invalid_grant", "message" => "Bad code"}}
      )

      assert {:error, %WorkOS.Error{error: "invalid_grant", message: "Bad code"}} =
               WorkOS.SSO.get_profile_and_token(opts |> Keyword.get(:code))
    end

    test "get_profile_and_token returns error on client error", context do
      opts = [code: "bad_code"]

      context
      |> ClientMock.get_profile_and_token(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.SSO.get_profile_and_token(opts |> Keyword.get(:code))
    end

    test "get_profile_and_token/2 returns error on 400", context do
      opts = [code: "bad_code"]

      context
      |> ClientMock.get_profile_and_token(
        assert_fields: opts,
        respond_with: {400, %{"error" => "invalid_grant", "message" => "Bad code"}}
      )

      assert {:error, %WorkOS.Error{error: "invalid_grant", message: "Bad code"}} =
               WorkOS.SSO.get_profile_and_token(WorkOS.client(), opts |> Keyword.get(:code))
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

    test "get_profile returns error on 404", context do
      opts = [access_token: "bad_token"]
      context |> ClientMock.get_profile(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.SSO.get_profile(opts |> Keyword.get(:access_token))
    end

    test "get_profile returns error on client error", context do
      opts = [access_token: "bad_token"]
      context |> ClientMock.get_profile(assert_fields: opts, respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.SSO.get_profile(opts |> Keyword.get(:access_token))
    end

    test "get_profile/2 returns error on 404", context do
      opts = [access_token: "bad_token"]
      context |> ClientMock.get_profile(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.SSO.get_profile(WorkOS.client(), opts |> Keyword.get(:access_token))
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

    test "get_connection returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.get_connection(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.SSO.get_connection(opts |> Keyword.get(:connection_id))
    end

    test "get_connection returns error on client error", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.get_connection(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.SSO.get_connection(opts |> Keyword.get(:connection_id))
    end

    test "get_connection/2 returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.get_connection(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.SSO.get_connection(WorkOS.client(), opts |> Keyword.get(:connection_id))
    end
  end

  describe "list_connections" do
    test "requests a list of connections", context do
      opts = [organization_id: "org_1234"]

      context |> ClientMock.list_connections(assert_fields: opts)

      assert {:ok, %WorkOS.List{data: [%WorkOS.SSO.Connection{}], list_metadata: %{}}} =
               WorkOS.SSO.list_connections(opts |> Enum.into(%{}))
    end

    test "without any options, returns connections and metadata", context do
      context |> ClientMock.list_connections()

      assert {:ok, %WorkOS.List{data: [%WorkOS.SSO.Connection{}], list_metadata: %{}}} =
               WorkOS.SSO.list_connections()
    end

    test "list_connections returns error on 500", context do
      context |> ClientMock.list_connections(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.SSO.list_connections(%{})
    end

    test "list_connections returns error on client error", context do
      context |> ClientMock.list_connections(respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.SSO.list_connections(%{})
    end

    test "list_connections/2 returns error on 500", context do
      context |> ClientMock.list_connections(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.SSO.list_connections(WorkOS.client(), %{})
    end
  end

  describe "delete_connection" do
    test "sends a request to delete a connection", context do
      opts = [connection_id: "conn_123"]

      context |> ClientMock.delete_connection(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.SSO.delete_connection(opts |> Keyword.get(:connection_id))
    end

    test "delete_connection returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.delete_connection(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.SSO.delete_connection(opts |> Keyword.get(:connection_id))
    end

    test "delete_connection returns error on client error", context do
      opts = [connection_id: "bad_conn"]

      context
      |> ClientMock.delete_connection(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.SSO.delete_connection(opts |> Keyword.get(:connection_id))
    end

    test "delete_connection/2 returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.delete_connection(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.SSO.delete_connection(WorkOS.client(), opts |> Keyword.get(:connection_id))
    end
  end

  describe "WorkOS.SSO.Connection.Domain" do
    test "struct creation and cast" do
      domain = %WorkOS.SSO.Connection.Domain{
        id: "domain_123",
        object: "connection_domain",
        domain: "example.com"
      }

      assert domain.id == "domain_123"
      assert domain.object == "connection_domain"
      assert domain.domain == "example.com"

      casted =
        WorkOS.SSO.Connection.Domain.cast(%{
          "id" => "domain_123",
          "object" => "connection_domain",
          "domain" => "example.com"
        })

      assert %WorkOS.SSO.Connection.Domain{id: "domain_123", domain: "example.com"} = casted
    end
  end

  describe "edge and error cases" do
    setup :setup_env

    test "get_profile_and_token returns error on 400", context do
      opts = [code: "bad_code"]

      context
      |> ClientMock.get_profile_and_token(
        assert_fields: opts,
        respond_with: {400, %{"error" => "invalid_grant", "message" => "Bad code"}}
      )

      assert {:error, %WorkOS.Error{error: "invalid_grant", message: "Bad code"}} =
               WorkOS.SSO.get_profile_and_token(opts |> Keyword.get(:code))
    end

    test "get_profile_and_token returns error on client error", context do
      opts = [code: "bad_code"]

      context
      |> ClientMock.get_profile_and_token(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.SSO.get_profile_and_token(opts |> Keyword.get(:code))
    end

    test "get_profile_and_token/2 returns error on 400", context do
      opts = [code: "bad_code"]

      context
      |> ClientMock.get_profile_and_token(
        assert_fields: opts,
        respond_with: {400, %{"error" => "invalid_grant", "message" => "Bad code"}}
      )

      assert {:error, %WorkOS.Error{error: "invalid_grant", message: "Bad code"}} =
               WorkOS.SSO.get_profile_and_token(WorkOS.client(), opts |> Keyword.get(:code))
    end

    test "get_profile returns error on 404", context do
      opts = [access_token: "bad_token"]
      context |> ClientMock.get_profile(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.SSO.get_profile(opts |> Keyword.get(:access_token))
    end

    test "get_profile returns error on client error", context do
      opts = [access_token: "bad_token"]
      context |> ClientMock.get_profile(assert_fields: opts, respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.SSO.get_profile(opts |> Keyword.get(:access_token))
    end

    test "get_profile/2 returns error on 404", context do
      opts = [access_token: "bad_token"]
      context |> ClientMock.get_profile(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.SSO.get_profile(WorkOS.client(), opts |> Keyword.get(:access_token))
    end

    test "get_connection returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.get_connection(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.SSO.get_connection(opts |> Keyword.get(:connection_id))
    end

    test "get_connection returns error on client error", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.get_connection(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.SSO.get_connection(opts |> Keyword.get(:connection_id))
    end

    test "get_connection/2 returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.get_connection(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.SSO.get_connection(WorkOS.client(), opts |> Keyword.get(:connection_id))
    end

    test "list_connections returns error on 500", context do
      context |> ClientMock.list_connections(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.SSO.list_connections(%{})
    end

    test "list_connections returns error on client error", context do
      context |> ClientMock.list_connections(respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.SSO.list_connections(%{})
    end

    test "list_connections/2 returns error on 500", context do
      context |> ClientMock.list_connections(respond_with: {500, %{}})
      assert {:error, _} = WorkOS.SSO.list_connections(WorkOS.client(), %{})
    end

    test "delete_connection returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.delete_connection(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.SSO.delete_connection(opts |> Keyword.get(:connection_id))
    end

    test "delete_connection returns error on client error", context do
      opts = [connection_id: "bad_conn"]

      context
      |> ClientMock.delete_connection(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.SSO.delete_connection(opts |> Keyword.get(:connection_id))
    end

    test "delete_connection/2 returns error on 404", context do
      opts = [connection_id: "bad_conn"]
      context |> ClientMock.delete_connection(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.SSO.delete_connection(WorkOS.client(), opts |> Keyword.get(:connection_id))
    end
  end

  describe "default-argument function heads" do
    test "calls default-argument versions for coverage" do
      Tesla.Mock.mock(fn
        %{method: :get, url: url} = req ->
          if String.contains?(url, "/connections/") do
            %Tesla.Env{status: 404, body: %{}}
          else
            if String.contains?(url, "/connections") do
              %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
            else
              %Tesla.Env{status: 404, body: %{}}
            end
          end

        %{method: :post, url: url, body: body} ->
          if String.contains?(url, "/sso/token") do
            %Tesla.Env{status: 404, body: %{}}
          else
            %Tesla.Env{status: 404, body: %{}}
          end
      end)

      assert {:ok, _} = WorkOS.SSO.list_connections()
      assert {:error, _} = WorkOS.SSO.get_profile_and_token(nil)
      assert {:error, _} = WorkOS.SSO.get_profile(nil)
      assert {:error, _} = WorkOS.SSO.get_connection(nil)
      assert {:error, _} = WorkOS.SSO.delete_connection(nil)
    end
  end

  describe "default-argument heads with no arguments" do
    test "calls list_connections/0 with no arguments for coverage" do
      Tesla.Mock.mock(fn
        %{method: :get, url: url} = req ->
          if String.contains?(url, "/connections") do
            %Tesla.Env{status: 200, body: %{"data" => [], "list_metadata" => %{}}}
          else
            %Tesla.Env{status: 404, body: %{}}
          end
      end)

      assert {:ok, _} = WorkOS.SSO.list_connections()
    end
  end

  describe "default-argument function heads (explicit coverage)" do
    setup :setup_env

    test "delete_connection/1 with valid and invalid args", context do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 404, body: %{}} end)
      assert {:error, _} = WorkOS.SSO.delete_connection(nil)
      # valid call (should error due to missing or invalid id, but covers the head)
      context
      |> ClientMock.delete_connection(
        assert_fields: [connection_id: "invalid_id"],
        respond_with: {404, %{}}
      )

      assert {:error, _} = WorkOS.SSO.delete_connection("invalid_id")
    end

    test "get_connection/1 with valid and invalid args", context do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 404, body: %{}} end)
      assert {:error, _} = WorkOS.SSO.get_connection(nil)

      context
      |> ClientMock.get_connection(
        assert_fields: [connection_id: "invalid_id"],
        respond_with: {404, %{}}
      )

      assert {:error, _} = WorkOS.SSO.get_connection("invalid_id")
    end

    test "get_profile_and_token/1 with valid and invalid args", context do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 404, body: %{}} end)
      assert {:error, _} = WorkOS.SSO.get_profile_and_token(nil)

      context
      |> ClientMock.get_profile_and_token(
        assert_fields: [code: "invalid_code"],
        respond_with: {400, %{"error" => "invalid_grant", "message" => "Bad code"}}
      )

      assert {:error, _} = WorkOS.SSO.get_profile_and_token("invalid_code")
    end

    test "get_profile/1 with valid and invalid args", context do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 404, body: %{}} end)
      assert {:error, _} = WorkOS.SSO.get_profile(nil)

      context
      |> ClientMock.get_profile(
        assert_fields: [access_token: "invalid_token"],
        respond_with: {404, %{}}
      )

      assert {:error, _} = WorkOS.SSO.get_profile("invalid_token")
    end
  end

  describe "get_authorization_url error branch" do
    test "returns error when required keys are missing" do
      # missing :connection, :organization, and :provider
      opts = %{redirect_uri: "example.com/sso/workos/callback"}
      assert {:error, _} = WorkOS.SSO.get_authorization_url(opts)
    end
  end
end

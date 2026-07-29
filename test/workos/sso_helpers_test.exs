# @oagen-ignore-file — hand-maintained tests for SSO PKCE and logout helpers.

defmodule WorkOS.SSOHelpersTest do
  use ExUnit.Case, async: true

  alias WorkOS.SSO.Logout

  setup do
    client =
      WorkOS.Client.new(
        api_key: "sk_test_key",
        client_id: "client_123",
        req_options: [plug: {Req.Test, WorkOS.Client}]
      )

    {:ok, client: client}
  end

  describe "WorkOS.SSO.PKCE" do
    test "get_authorization_url generates PKCE and state automatically", %{client: client} do
      result =
        WorkOS.SSO.PKCE.get_authorization_url(client, %{redirect_uri: "https://example.com/cb"})

      assert %{url: url, code_verifier: verifier, state: state} = result
      assert url =~ "/sso/authorize"

      query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      assert query["client_id"] == "client_123"
      assert query["code_challenge"] == WorkOS.PKCE.generate_code_challenge(verifier)
      assert query["code_challenge_method"] == "S256"
      assert query["state"] == state
    end

    test "code_exchange posts the code and verifier to /sso/token", %{client: client} do
      Req.Test.stub(WorkOS.Client, fn conn ->
        assert conn.request_path == "/sso/token"

        {:ok, req_body, conn} = Plug.Conn.read_body(conn)
        req_body = JSON.decode!(req_body)
        assert req_body["grant_type"] == "authorization_code"
        assert req_body["code"] == "code_123"
        assert req_body["code_verifier"] == "verifier_123"
        assert req_body["client_id"] == "client_123"

        Req.Test.json(conn, WorkOS.TestFixtures.fixture("sso/get_profile_and_token"))
      end)

      assert {:ok, %WorkOS.SSOTokenResponse{}} =
               WorkOS.SSO.PKCE.code_exchange(client, %{
                 code: "code_123",
                 code_verifier: "verifier_123"
               })
    end
  end

  describe "WorkOS.SSO.Logout" do
    test "get_logout_url authorizes a logout token then builds the URL", %{client: client} do
      Req.Test.stub(WorkOS.Client, fn conn ->
        assert conn.request_path == "/sso/logout/authorize"

        {:ok, req_body, conn} = Plug.Conn.read_body(conn)
        assert JSON.decode!(req_body)["profile_id"] == "prof_123"

        Req.Test.json(conn, %{
          "logout_url" => "https://api.workos.com/sso/logout?token=logout_token_123",
          "logout_token" => "logout_token_123"
        })
      end)

      assert {:ok, url} = Logout.get_logout_url(client, %{profile_id: "prof_123"})

      assert url =~ "/sso/logout"
      assert url =~ "token=logout_token_123"
    end

    test "get_logout_url appends return_to", %{client: client} do
      Req.Test.stub(WorkOS.Client, fn conn ->
        Req.Test.json(conn, %{"logout_token" => "logout_token_123"})
      end)

      assert {:ok, url} =
               Logout.get_logout_url(client, %{
                 profile_id: "prof_123",
                 return_to: "https://example.com/bye"
               })

      assert url =~ "return_to=" <> URI.encode_www_form("https://example.com/bye")
    end

    test "get_logout_url surfaces authorize errors", %{client: client} do
      Req.Test.stub(WorkOS.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Not found"})
      end)

      assert {:error, %WorkOS.ApiError{status: 404}} =
               Logout.get_logout_url(client, %{profile_id: "prof_missing"})
    end
  end
end

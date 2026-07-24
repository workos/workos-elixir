# @oagen-ignore-file — hand-maintained tests for sealed session helpers.

defmodule WorkOS.SessionTest do
  use ExUnit.Case, async: true

  @cookie_password Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)

  defp build_client do
    WorkOS.Client.new(
      api_key: "sk_test_key",
      client_id: "client_123",
      req_options: [plug: {Req.Test, WorkOS.Client}]
    )
  end

  defp jwt(claims) do
    header = %{"alg" => "RS256", "typ" => "JWT"} |> JSON.encode!() |> url64()
    payload = claims |> JSON.encode!() |> url64()
    "#{header}.#{payload}.#{url64("stub-signature")}"
  end

  defp url64(data), do: Base.url_encode64(data, padding: false)

  defp claims(overrides \\ %{}) do
    Map.merge(
      %{
        "sid" => "session_123",
        "org_id" => "org_123",
        "role" => "admin",
        "permissions" => ["posts:read"],
        "entitlements" => ["audit-logs"],
        "exp" => System.system_time(:second) + 3600
      },
      overrides
    )
  end

  defp sealed_session(claim_overrides \\ %{}) do
    {:ok, sealed} =
      WorkOS.Session.seal_session(
        %{
          access_token: jwt(claims(claim_overrides)),
          refresh_token: "refresh_token_123",
          user: %WorkOS.User{id: "user_123", email: "user@example.com"},
          impersonator: nil
        },
        @cookie_password
      )

    sealed
  end

  describe "raw seal/unseal" do
    test "roundtrips arbitrary data" do
      data = %{"hello" => "world", "count" => 3}

      assert {:ok, sealed} = WorkOS.Session.seal_data(data, @cookie_password)
      assert {:ok, ^data} = WorkOS.Session.unseal_data(sealed, @cookie_password)
    end

    test "derives a key from non-hex passwords" do
      assert {:ok, sealed} = WorkOS.Session.seal_data(%{"a" => 1}, "plain passphrase")
      assert {:ok, %{"a" => 1}} = WorkOS.Session.unseal_data(sealed, "plain passphrase")
    end

    test "fails to unseal with the wrong password" do
      assert {:ok, sealed} = WorkOS.Session.seal_data(%{"a" => 1}, @cookie_password)

      assert {:error, :decryption_failed} =
               WorkOS.Session.unseal_data(sealed, "wrong password")
    end

    test "rejects an empty password" do
      assert {:error, :empty_cookie_password} = WorkOS.Session.seal_data(%{}, "")
      assert {:error, :empty_cookie_password} = WorkOS.Session.unseal_data("abc", "")
    end

    test "rejects garbage sealed input" do
      assert {:error, :invalid_base64} = WorkOS.Session.unseal_data("!!!", @cookie_password)

      assert {:error, :sealed_data_too_short} =
               WorkOS.Session.unseal_data("YWJj", @cookie_password)
    end
  end

  describe "authenticate" do
    test "authenticates a valid sealed session and extracts claims" do
      result = WorkOS.Session.authenticate(sealed_session(), @cookie_password)

      assert result.authenticated
      assert result.session_id == "session_123"
      assert result.organization_id == "org_123"
      assert result.role == "admin"
      assert result.permissions == ["posts:read"]
      assert result.entitlements == ["audit-logs"]
      assert %WorkOS.User{id: "user_123"} = result.user
      refute result.needs_refresh
    end

    test "flags an expired access token as needing refresh" do
      expired = sealed_session(%{"exp" => System.system_time(:second) - 60})
      result = WorkOS.Session.authenticate(expired, @cookie_password)

      refute result.authenticated
      assert result.needs_refresh
      assert result.reason == "session_expired"
      assert result.session_id == "session_123"
    end

    test "reports a missing cookie" do
      result = WorkOS.Session.authenticate(nil, @cookie_password)

      refute result.authenticated
      assert result.reason == "no_session_cookie_provided"
    end

    test "reports an invalid cookie" do
      result = WorkOS.Session.authenticate("not-a-session", @cookie_password)

      refute result.authenticated
      assert result.reason == "invalid_session_cookie"
    end

    test "reports a cookie without an access token" do
      {:ok, sealed} = WorkOS.Session.seal_session(%{refresh_token: "rt"}, @cookie_password)
      result = WorkOS.Session.authenticate(sealed, @cookie_password)

      refute result.authenticated
      assert result.reason == "invalid_jwt"
    end
  end

  describe "refresh" do
    test "exchanges the refresh token and reseals the session" do
      new_access_token = jwt(claims(%{"sid" => "session_456"}))

      Req.Test.stub(WorkOS.Client, fn conn ->
        assert conn.request_path == "/user_management/authenticate"

        {:ok, req_body, conn} = Plug.Conn.read_body(conn)
        req_body = JSON.decode!(req_body)
        assert req_body["grant_type"] == "refresh_token"
        assert req_body["refresh_token"] == "refresh_token_123"
        assert req_body["organization_id"] == "org_123"

        Req.Test.json(conn, %{
          "access_token" => new_access_token,
          "refresh_token" => "refresh_token_456",
          "user" => %{"object" => "user", "id" => "user_123", "email" => "user@example.com"}
        })
      end)

      session = WorkOS.Session.new(build_client(), sealed_session(), @cookie_password)

      assert {:ok, %{authenticated: true, sealed_session: resealed}} =
               WorkOS.Session.refresh(session)

      result = WorkOS.Session.authenticate(resealed, @cookie_password)
      assert result.authenticated
      assert result.session_id == "session_456"
    end

    test "maps a revoked refresh token to its reason" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"code" => "invalid_grant", "message" => "Revoked"})
      end)

      assert {:error, %{reason: "refresh_token_revoked", error: %WorkOS.ApiError{}}} =
               WorkOS.Session.refresh_session(
                 build_client(),
                 sealed_session(),
                 @cookie_password
               )
    end

    test "reports structural problems without calling the API" do
      assert {:error, %{reason: "no_session_cookie_provided"}} =
               WorkOS.Session.refresh_session(build_client(), nil, @cookie_password)

      assert {:error, %{reason: "invalid_session_cookie"}} =
               WorkOS.Session.refresh_session(build_client(), "garbage", @cookie_password)
    end
  end

  describe "get_logout_url" do
    test "builds the logout URL from the session ID" do
      session = WorkOS.Session.new(build_client(), sealed_session(), @cookie_password)

      assert {:ok, url} = WorkOS.Session.get_logout_url(session)
      assert url =~ "/user_management/sessions/logout"
      assert url =~ "session_id=session_123"
    end

    test "appends return_to when given" do
      session = WorkOS.Session.new(build_client(), sealed_session(), @cookie_password)

      assert {:ok, url} =
               WorkOS.Session.get_logout_url(session, return_to: "https://example.com/goodbye")

      assert url =~ "return_to=" <> URI.encode_www_form("https://example.com/goodbye")
    end

    test "works for an expired session" do
      expired = sealed_session(%{"exp" => System.system_time(:second) - 60})
      session = WorkOS.Session.new(build_client(), expired, @cookie_password)

      assert {:ok, url} = WorkOS.Session.get_logout_url(session)
      assert url =~ "session_id=session_123"
    end
  end

  test "seal_session_from_auth_response produces an authenticatable session" do
    response = %WorkOS.AuthenticateResponse{
      access_token: jwt(claims()),
      refresh_token: "refresh_token_123",
      user: %WorkOS.User{id: "user_123", email: "user@example.com"}
    }

    assert {:ok, sealed} =
             WorkOS.Session.seal_session_from_auth_response(response, @cookie_password)

    result = WorkOS.Session.authenticate(sealed, @cookie_password)
    assert result.authenticated
    assert %WorkOS.User{id: "user_123"} = result.user
  end
end

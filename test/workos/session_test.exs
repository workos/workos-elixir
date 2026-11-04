# @oagen-ignore-file — hand-maintained tests for sealed session helpers.

defmodule WorkOS.SessionTest do
  use ExUnit.Case, async: true

  @cookie_password Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)
  @signing_key JOSE.JWK.generate_key({:rsa, 2048})
  @other_key JOSE.JWK.generate_key({:rsa, 2048})
  @kid "key_123"

  setup do
    stub_api(fn conn -> flunk("unexpected request to #{conn.request_path}") end)
    :ok
  end

  # Each client gets its own client_id so the per-URL JWKS cache is not shared
  # between async tests.
  defp build_client do
    WorkOS.Client.new(
      api_key: "sk_test_key",
      client_id: "client_#{System.unique_integer([:positive])}",
      req_options: [plug: {Req.Test, WorkOS.Client}]
    )
  end

  defp stub_api(handler) do
    test_pid = self()

    Req.Test.stub(WorkOS.Client, fn conn ->
      if String.starts_with?(conn.request_path, "/sso/jwks/") do
        send(test_pid, :jwks_fetched)
        Req.Test.json(conn, %{"keys" => [public_jwk(@signing_key)]})
      else
        handler.(conn)
      end
    end)
  end

  defp public_jwk(key) do
    {_kty, jwk} = key |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
    Map.merge(jwk, %{"kid" => @kid, "alg" => "RS256", "use" => "sig"})
  end

  defp jwt(claims, opts \\ []) do
    key = Keyword.get(opts, :key, @signing_key)
    header = %{"alg" => "RS256", "kid" => Keyword.get(opts, :kid, @kid)}
    {_jws, token} = key |> JOSE.JWT.sign(header, claims) |> JOSE.JWS.compact()
    token
  end

  defp authenticate(sealed) do
    build_client()
    |> WorkOS.Session.new(sealed, @cookie_password)
    |> WorkOS.Session.authenticate()
  end

  defp claims(overrides \\ %{}) do
    Map.merge(
      %{
        "sub" => "user_123",
        "sid" => "session_123",
        "auth_time" => System.system_time(:second),
        "org_id" => "org_123",
        "role" => "admin",
        "permissions" => ["posts:read"],
        "entitlements" => ["audit-logs"],
        "exp" => System.system_time(:second) + 3600
      },
      overrides
    )
  end

  defp sealed_session(claim_overrides \\ %{}, jwt_opts \\ []) do
    {:ok, sealed} =
      WorkOS.Session.seal_session(
        %{
          access_token: jwt(claims(claim_overrides), jwt_opts),
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
      result = authenticate(sealed_session())

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
      result = authenticate(expired)

      refute result.authenticated
      assert result.needs_refresh
      assert result.reason == "session_expired"
      assert result.session_id == "session_123"
    end

    test "reports a missing cookie" do
      result = authenticate(nil)

      refute result.authenticated
      assert result.reason == "no_session_cookie_provided"
    end

    test "reports an invalid cookie" do
      result = authenticate("not-a-session")

      refute result.authenticated
      assert result.reason == "invalid_session_cookie"
    end

    test "reports a cookie without an access token" do
      {:ok, sealed} = WorkOS.Session.seal_session(%{refresh_token: "rt"}, @cookie_password)
      result = authenticate(sealed)

      refute result.authenticated
      assert result.reason == "invalid_jwt"
    end

    test "rejects an access token with an invalid signature" do
      result = authenticate(sealed_session(%{}, key: @other_key))

      refute result.authenticated
      assert result.reason == "invalid_jwt"
      assert result.session_id == nil
    end

    test "rejects an access token signed by an unknown key" do
      result = authenticate(sealed_session(%{}, key: @other_key, kid: "unknown_key"))

      refute result.authenticated
      assert result.reason == "invalid_jwt"
    end

    test "rejects an unsigned access token" do
      header = Base.url_encode64(~s({"alg":"none","kid":"#{@kid}"}), padding: false)
      payload = claims() |> JSON.encode!() |> Base.url_encode64(padding: false)

      {:ok, sealed} =
        WorkOS.Session.seal_session(%{access_token: "#{header}.#{payload}."}, @cookie_password)

      result = authenticate(sealed)

      refute result.authenticated
      assert result.reason == "invalid_jwt"
    end

    test "accepts a user access token with sub_profile user" do
      assert authenticate(sealed_session(%{"sub_profile" => "user"})).authenticated
    end

    test "rejects agent access tokens" do
      result =
        authenticate(
          sealed_session(%{"sub" => "agent_123", "sub_profile" => "ai_agent", "auth_time" => nil})
        )

      refute result.authenticated
      assert result.reason == "invalid_jwt"
    end

    test "rejects widget access tokens" do
      result = authenticate(sealed_session(%{"sub_type" => "authkit"}))

      refute result.authenticated
      assert result.reason == "invalid_jwt"
    end

    test "rejects access tokens without auth_time" do
      result = authenticate(sealed_session(%{"auth_time" => nil}))

      refute result.authenticated
      assert result.reason == "invalid_jwt"
    end

    test "rejects expired non-user access tokens instead of asking for a refresh" do
      expired =
        sealed_session(%{"sub_type" => "authkit", "exp" => System.system_time(:second) - 60})

      result = authenticate(expired)

      refute result.needs_refresh
      assert result.reason == "invalid_jwt"
    end

    test "caches the JWKS across authentications" do
      client = build_client()
      session = WorkOS.Session.new(client, sealed_session(), @cookie_password)

      assert WorkOS.Session.authenticate(session).authenticated
      assert WorkOS.Session.authenticate(session).authenticated

      assert_received :jwks_fetched
      refute_received :jwks_fetched
    end

    test "raises when the JWKS cannot be fetched" do
      Req.Test.stub(WorkOS.Client, fn conn ->
        conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{"message" => "Not found"})
      end)

      assert_raise WorkOS.ApiError, fn -> authenticate(sealed_session()) end
    end
  end

  describe "authenticate without a client (deprecated)" do
    test "reads the claims without verifying the signature" do
      sealed = sealed_session(%{}, key: @other_key)

      result =
        nil |> WorkOS.Session.new(sealed, @cookie_password) |> WorkOS.Session.authenticate()

      assert result.authenticated
      assert result.session_id == "session_123"
    end
  end

  describe "refresh" do
    test "exchanges the refresh token and reseals the session" do
      new_access_token = jwt(claims(%{"sid" => "session_456"}))

      stub_api(fn conn ->
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

      result = authenticate(resealed)
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

    result = authenticate(sealed)
    assert result.authenticated
    assert %WorkOS.User{id: "user_123"} = result.user
  end
end

# @oagen-ignore-file — hand-maintained tests for AuthKit flow helpers.

defmodule WorkOS.AuthKitTest do
  use ExUnit.Case, async: true

  setup do
    client =
      WorkOS.Client.new(
        api_key: "sk_test_key",
        client_id: "client_123",
        req_options: [plug: {Req.Test, WorkOS.Client}]
      )

    {:ok, client: client}
  end

  test "get_authorization_url builds an AuthKit URL", %{client: client} do
    url = WorkOS.AuthKit.get_authorization_url(client, %{redirect_uri: "https://example.com/cb"})

    assert url =~ "/user_management/authorize"
    assert url =~ "client_id=client_123"
    assert url =~ "response_type=code"
    assert url =~ URI.encode_www_form("https://example.com/cb")
  end

  test "get_pkce_authorization_url generates PKCE and state automatically", %{client: client} do
    result =
      WorkOS.AuthKit.get_pkce_authorization_url(client, %{redirect_uri: "https://example.com/cb"})

    assert %{url: url, code_verifier: verifier, state: state} = result
    assert is_binary(verifier) and byte_size(verifier) >= 43
    assert is_binary(state) and state != ""

    expected_challenge = WorkOS.PKCE.generate_code_challenge(verifier)
    query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert query["code_challenge"] == expected_challenge
    assert query["code_challenge_method"] == "S256"
    assert query["state"] == state
  end

  test "get_pkce_authorization_url keeps a caller-provided state", %{client: client} do
    result = WorkOS.AuthKit.get_pkce_authorization_url(client, %{state: "my-state"})

    assert result.state == "my-state"
    assert result.url =~ "state=my-state"
  end

  test "pkce_code_exchange sends code and code_verifier", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert conn.request_path == "/user_management/authenticate"

      {:ok, req_body, conn} = Plug.Conn.read_body(conn)
      req_body = JSON.decode!(req_body)
      assert req_body["grant_type"] == "authorization_code"
      assert req_body["code"] == "code_123"
      assert req_body["code_verifier"] == "verifier_123"
      assert req_body["client_id"] == "client_123"

      Req.Test.json(conn, WorkOS.TestFixtures.fixture("user_management/authenticate_with_code"))
    end)

    assert {:ok, %WorkOS.AuthenticateResponse{}} =
             WorkOS.AuthKit.pkce_code_exchange(client, %{
               code: "code_123",
               code_verifier: "verifier_123"
             })
  end

  test "start_device_authorization injects the configured client_id", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert conn.request_path == "/user_management/authorize/device"

      {:ok, req_body, conn} = Plug.Conn.read_body(conn)
      assert JSON.decode!(req_body)["client_id"] == "client_123"

      Req.Test.json(conn, %{
        "device_code" => "device_code_123",
        "user_code" => "ABCD-1234",
        "verification_uri" => "https://auth.workos.com/device",
        "verification_uri_complete" => "https://auth.workos.com/device?user_code=ABCD-1234",
        "expires_in" => 300,
        "interval" => 5
      })
    end)

    assert {:ok, %WorkOS.DeviceAuthorizationResponse{device_code: "device_code_123"}} =
             WorkOS.AuthKit.start_device_authorization(client)
  end

  test "poll_device_code returns once authorization completes", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      {:ok, req_body, conn} = Plug.Conn.read_body(conn)
      req_body = JSON.decode!(req_body)
      assert req_body["grant_type"] == "urn:ietf:params:oauth:grant-type:device_code"
      assert req_body["device_code"] == "device_code_123"

      Req.Test.json(
        conn,
        WorkOS.TestFixtures.fixture("user_management/authenticate_with_device_code")
      )
    end)

    assert {:ok, %WorkOS.AuthenticateResponse{}} =
             WorkOS.AuthKit.poll_device_code(client, "device_code_123", interval: 0)
  end

  test "poll_device_code keeps polling while authorization is pending", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"code" => "authorization_pending", "message" => "Pending"})
    end)

    assert {:error, %WorkOS.ApiError{code: "authorization_pending"}} =
             WorkOS.AuthKit.poll_device_code(client, "device_code_123",
               interval: 0,
               max_attempts: 3
             )
  end
end

# @oagen-ignore-file — hand-maintained tests for JWKS helpers.

defmodule WorkOS.JWKSTest do
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

  test "url uses the configured client_id", %{client: client} do
    assert WorkOS.JWKS.url(client) == "#{client.base_url}/sso/jwks/client_123"
  end

  test "url accepts an explicit client_id", %{client: client} do
    assert WorkOS.JWKS.url(client, "client_456") == "#{client.base_url}/sso/jwks/client_456"
  end

  test "url raises without any client_id", %{client: client} do
    assert_raise ArgumentError, fn -> WorkOS.JWKS.url(%{client | client_id: nil}) end
  end

  test "fetch retrieves the JWKS", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert conn.request_path == "/sso/jwks/client_123"
      Req.Test.json(conn, WorkOS.TestFixtures.fixture("user_management/get_jwks"))
    end)

    assert {:ok, %WorkOS.JwksResponse{}} = WorkOS.JWKS.fetch(client)
  end
end

# @oagen-ignore-file — hand-maintained tests for the hand-maintained Passwordless module.

defmodule WorkOS.PasswordlessTest do
  use ExUnit.Case, async: true

  setup do
    client =
      WorkOS.Client.new(
        api_key: "sk_test_key",
        req_options: [plug: {Req.Test, WorkOS.Client}]
      )

    {:ok, client: client}
  end

  test "create_session posts to /passwordless/sessions and defaults the type", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/passwordless/sessions"

      {:ok, req_body, conn} = Plug.Conn.read_body(conn)
      req_body = JSON.decode!(req_body)
      assert req_body["email"] == "user@example.com"
      assert req_body["type"] == "MagicLink"

      Req.Test.json(conn, %{
        "id" => "passwordless_session_123",
        "email" => "user@example.com",
        "expires_at" => "2026-01-01T00:00:00.000Z",
        "link" => "https://auth.workos.com/passwordless/token/confirm",
        "object" => "passwordless_session"
      })
    end)

    assert {:ok, %WorkOS.Passwordless.Session{} = session} =
             WorkOS.Passwordless.create_session(client, %{email: "user@example.com"})

    assert session.id == "passwordless_session_123"
    assert session.link =~ "workos.com"
  end

  test "send_session posts to /passwordless/sessions/:id/send", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/passwordless/sessions/passwordless_session_123/send"
      Req.Test.json(conn, %{"success" => true})
    end)

    assert {:ok, %{"success" => true}} =
             WorkOS.Passwordless.send_session(client, "passwordless_session_123")
  end

  test "surfaces API errors as tagged tuples", %{client: client} do
    Req.Test.stub(WorkOS.Client, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{"message" => "Email required"})
    end)

    assert {:error, %WorkOS.ApiError{status: 422}} =
             WorkOS.Passwordless.create_session(client, %{})
  end
end

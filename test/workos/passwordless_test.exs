defmodule WorkOS.PasswordlessTest do
  use WorkOS.TestCase

  alias WorkOS.Passwordless.ClientMock

  setup :setup_env

  describe "create_session" do
    test "with valid options, creates a passwordless session", context do
      opts = [
        email: "passwordless-session-email@workos.com",
        type: "MagicLink",
        redirect_uri: "https://example.com/passwordless/callback"
      ]

      context |> ClientMock.create_session(assert_fields: opts)

      assert {:ok, %WorkOS.Passwordless.Session{email: email}} =
               WorkOS.Passwordless.create_session(opts |> Enum.into(%{}))

      refute is_nil(email)
    end
  end

  describe "send_session" do
    test "with a valid session id, sends a request to send a magic link email", context do
      opts = [session_id: "session_123"]

      context |> ClientMock.send_session(assert_fields: opts)

      assert {:ok, %WorkOS.Passwordless.Session.Send{success: success}} =
               WorkOS.Passwordless.send_session(opts |> Keyword.get(:session_id))

      assert success = true
    end
  end
end

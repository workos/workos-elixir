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

      assert success == true
    end
  end

  describe "edge and error cases" do
    setup :setup_env

    test "create_session returns error on 400", context do
      opts = [email: "bad-email@workos.com", type: "MagicLink"]

      context
      |> ClientMock.create_session(
        assert_fields: opts,
        respond_with: {400, %{"error" => "invalid_email"}}
      )

      assert {:error, %WorkOS.Error{error: "invalid_email"}} =
               WorkOS.Passwordless.create_session(opts |> Enum.into(%{}))
    end

    test "create_session returns error on client error", context do
      opts = [email: "bad-email@workos.com", type: "MagicLink"]
      context |> ClientMock.create_session(assert_fields: opts, respond_with: {:error, :nxdomain})
      assert {:error, :client_error} = WorkOS.Passwordless.create_session(opts |> Enum.into(%{}))
    end

    test "create_session/2 returns error on 400", context do
      opts = [email: "bad-email@workos.com", type: "MagicLink"]

      context
      |> ClientMock.create_session(
        assert_fields: opts,
        respond_with: {400, %{"error" => "invalid_email"}}
      )

      assert {:error, %WorkOS.Error{error: "invalid_email"}} =
               WorkOS.Passwordless.create_session(WorkOS.client(), opts |> Enum.into(%{}))
    end

    test "send_session returns error on 404", context do
      opts = [session_id: "bad_session"]
      context |> ClientMock.send_session(assert_fields: opts, respond_with: {404, %{}})
      assert {:error, _} = WorkOS.Passwordless.send_session(opts |> Keyword.get(:session_id))
    end

    test "send_session returns error on client error", context do
      opts = [session_id: "bad_session"]
      context |> ClientMock.send_session(assert_fields: opts, respond_with: {:error, :nxdomain})

      assert {:error, :client_error} =
               WorkOS.Passwordless.send_session(opts |> Keyword.get(:session_id))
    end

    test "send_session/2 returns error on 404", context do
      opts = [session_id: "bad_session"]
      context |> ClientMock.send_session(assert_fields: opts, respond_with: {404, %{}})

      assert {:error, _} =
               WorkOS.Passwordless.send_session(WorkOS.client(), opts |> Keyword.get(:session_id))
    end

    test "create_session raises if :email is missing" do
      opts = %{type: "MagicLink"}

      assert_raise FunctionClauseError, fn ->
        WorkOS.Passwordless.create_session(opts)
      end
    end

    test "create_session raises if :type is missing" do
      opts = %{email: "test@workos.com"}

      assert_raise FunctionClauseError, fn ->
        WorkOS.Passwordless.create_session(opts)
      end
    end
  end
end

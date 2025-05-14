defmodule WorkOS.UserManagementTest do
  use WorkOS.TestCase

  alias WorkOS.UserManagement.ClientMock

  setup :setup_env

  def parse_uri(url) do
    uri = URI.parse(url)
    %URI{uri | query: URI.query_decoder(uri.query) |> Enum.to_list()}
  end

  describe "get_authorization_url" do
    test "generates an authorize url with the default `base_url`" do
      opts = [
        connection_id: "mock-connection-id",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert WorkOS.base_url() =~ parse_uri(success_url).host
    end

    test "generates an authorize url with a `provider`" do
      opts = [provider: "MicrosoftOAuth", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert {"provider", "MicrosoftOAuth"} in parse_uri(success_url).query
    end

    test "generates an authorize url with a `connection_id`" do
      opts = [
        connection_id: "mock-connection-id",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert {"connection_id", "mock-connection-id"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a `organization_id`" do
      opts = [
        organization_id: "mock-organization",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert {"organization_id", "mock-organization"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a custom `base_url` from app config" do
      initial_config = Application.get_env(:workos, WorkOS.Client)

      Application.put_env(
        :workos,
        WorkOS.Client,
        Keyword.put(initial_config, :base_url, "https://custom-base-url.com")
      )

      opts = [provider: "GoogleOAuth", redirect_uri: "example.com/sso/workos/callback"]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert "custom-base-url.com" == parse_uri(success_url).host

      Application.put_env(:workos, WorkOS.Client, initial_config)
    end

    test "generates an authorization url with a `state`" do
      opts = [
        provider: "GoogleOAuth",
        state: "mock-state",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert {"state", "mock-state"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a given `domain_hint`" do
      opts = [
        organization_id: "mock-organization",
        domain_hint: "mock-domain-hint",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert {"domain_hint", "mock-domain-hint"} in parse_uri(success_url).query
    end

    test "generates an authorization url with a given `login_hint`" do
      opts = [
        organization_id: "mock-organization",
        login_hint: "mock-login-hint",
        redirect_uri: "example.com/sso/workos/callback"
      ]

      assert {:ok, success_url} =
               opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()

      assert {"login_hint", "mock-login-hint"} in parse_uri(success_url).query
    end

    test "with a invalid selector, returns error" do
      opts = [
        redirect_uri: "example.com/sso/workos/callback"
      ]

      {:error, _message} = opts |> Map.new() |> WorkOS.UserManagement.get_authorization_url()
    end
  end

  describe "get_user" do
    test "requests a user", context do
      opts = [user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.get_user(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.User{id: id}} =
               WorkOS.UserManagement.get_user(opts |> Keyword.get(:user_id))

      refute is_nil(id)
    end
  end

  describe "list_users" do
    test "without any options, returns users and metadata", context do
      context
      |> ClientMock.list_users()

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.User{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_users()
    end

    test "with the email option, forms the proper request to the API", context do
      opts = [email: "test@example.com"]

      context
      |> ClientMock.list_users(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.User{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_users()
    end
  end

  describe "create_user" do
    test "with a valid payload, creates a user", context do
      opts = [email: "test@example.com"]

      context |> ClientMock.create_user(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.User{id: id}} =
               WorkOS.UserManagement.create_user(opts |> Enum.into(%{}))

      refute is_nil(id)
    end
  end

  describe "update_user" do
    test "with a valid payload, updates a user", context do
      opts = [
        user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS",
        first_name: "Foo test",
        last_name: "Foo test"
      ]

      context |> ClientMock.update_user(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.User{id: id}} =
               WorkOS.UserManagement.update_user(
                 opts |> Keyword.get(:user_id),
                 opts |> Enum.into(%{})
               )

      refute is_nil(id)
    end

    test "update_user/3 returns error when user_id is missing" do
      assert_raise Tesla.Mock.Error, fn ->
        WorkOS.UserManagement.update_user(nil, %{})
      end
    end
  end

  describe "delete_user" do
    test "sends a request to delete a user", context do
      opts = [user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.delete_user(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.UserManagement.delete_user(opts |> Keyword.get(:user_id))
    end
  end

  describe "authenticate_with_password" do
    test "with a valid payload, authenticates with password", context do
      opts = [email: "test@example.com", password: "foo-bar"]

      context |> ClientMock.authenticate(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Authentication{user: user}} =
               WorkOS.UserManagement.authenticate_with_password(opts |> Enum.into(%{}))

      refute is_nil(user["id"])
    end
  end

  describe "authenticate_with_code" do
    test "with a valid payload, authenticates with code", context do
      opts = [code: "foo-bar"]

      context |> ClientMock.authenticate(assert_fields: opts)

      assert {:ok, auth = %WorkOS.UserManagement.Authentication{}} =
               WorkOS.UserManagement.authenticate_with_code(opts |> Enum.into(%{}))

      refute is_nil(auth.user["id"])
      refute is_nil(auth.access_token)
      refute is_nil(auth.refresh_token)
    end
  end

  describe "authenticate_with_magic_auth" do
    test "with a valid payload, authenticates with magic auth", context do
      opts = [code: "foo-bar", email: "test@example.com"]

      context |> ClientMock.authenticate(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Authentication{user: user}} =
               WorkOS.UserManagement.authenticate_with_magic_auth(opts |> Enum.into(%{}))

      refute is_nil(user["id"])
    end
  end

  describe "authenticate_with_email_verification" do
    test "with a valid payload, authenticates with email verification", context do
      opts = [code: "foo-bar", pending_authentication_code: "foo-bar"]

      context |> ClientMock.authenticate(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Authentication{user: user}} =
               WorkOS.UserManagement.authenticate_with_email_verification(opts |> Enum.into(%{}))

      refute is_nil(user["id"])
    end
  end

  describe "authenticate_with_totp" do
    test "with a valid payload, authenticates with MFA TOTP", context do
      opts = [
        code: "foo-bar",
        authentication_challenge_id: "auth_challenge_1234",
        pending_authentication_code: "foo-bar"
      ]

      context |> ClientMock.authenticate(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Authentication{user: user}} =
               WorkOS.UserManagement.authenticate_with_totp(opts |> Enum.into(%{}))

      refute is_nil(user["id"])
    end
  end

  describe "authenticate_with_selected_organization" do
    test "with a valid payload, authenticates with a selected organization", context do
      opts = [
        pending_authentication_code: "foo-bar",
        organization_id: "organization_01H5JQDV7R7ATEYZDEG0W5PRYS"
      ]

      context |> ClientMock.authenticate(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Authentication{user: user}} =
               WorkOS.UserManagement.authenticate_with_selected_organization(
                 opts
                 |> Enum.into(%{})
               )

      refute is_nil(user["id"])
    end
  end

  describe "send_magic_auth_code" do
    test "with a valid payload, sends magic auth code email", context do
      opts = [
        email: "test@example.com"
      ]

      context |> ClientMock.send_magic_auth_code(assert_fields: opts)

      assert :ok = WorkOS.UserManagement.send_magic_auth_code(opts |> Keyword.get(:email))
    end
  end

  describe "enroll_auth_factor" do
    test "with a valid payload, enrolls auth factor", context do
      opts = [
        type: "totp",
        user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"
      ]

      context |> ClientMock.enroll_auth_factor(assert_fields: opts)

      assert {:ok,
              %WorkOS.UserManagement.MultiFactor.EnrollAuthFactor{
                challenge: challenge,
                factor: factor
              }} =
               WorkOS.UserManagement.enroll_auth_factor(
                 opts |> Keyword.get(:user_id),
                 opts |> Enum.into(%{})
               )

      refute is_nil(challenge["id"])
      refute is_nil(factor["id"])
    end
  end

  describe "list_auth_factors" do
    test "without any options, returns auth factors and metadata", context do
      opts = [
        user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"
      ]

      context
      |> ClientMock.list_auth_factors(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.MultiFactor.AuthenticationFactor{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_auth_factors(opts |> Keyword.get(:user_id))
    end
  end

  describe "send_verification_email" do
    test "with a valid payload, revokes an invitation", context do
      opts = [user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.send_verification_email(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.EmailVerification.SendVerificationEmail{user: user}} =
               WorkOS.UserManagement.send_verification_email(opts |> Keyword.get(:user_id))

      refute is_nil(user["id"])
    end
  end

  describe "verify_email" do
    test "with a valid payload, verifies user email", context do
      opts = [
        user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS",
        code: "Foo test"
      ]

      context |> ClientMock.verify_email(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.EmailVerification.VerifyEmail{user: user}} =
               WorkOS.UserManagement.verify_email(
                 opts |> Keyword.get(:user_id),
                 opts |> Enum.into(%{})
               )

      refute is_nil(user["id"])
    end
  end

  describe "send_password_reset_email" do
    test "with a valid payload, sends password reset email", context do
      opts = [
        email: "test@example.com",
        password_reset_url: "https://reset-password-test.com"
      ]

      context |> ClientMock.send_password_reset_email(assert_fields: opts)

      assert :ok = WorkOS.UserManagement.send_password_reset_email(opts |> Enum.into(%{}))
    end
  end

  describe "reset_password" do
    test "with a valid payload, resets password", context do
      opts = [
        token: ~c"test",
        new_password: ~c"test"
      ]

      context |> ClientMock.reset_password(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.ResetPassword{user: user}} =
               WorkOS.UserManagement.reset_password(opts |> Enum.into(%{}))

      refute is_nil(user["id"])
    end
  end

  describe "get_organization_membership" do
    test "requests an organization membership", context do
      opts = [organization_membership_id: "om_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.get_organization_membership(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.OrganizationMembership{id: id}} =
               WorkOS.UserManagement.get_organization_membership(
                 opts
                 |> Keyword.get(:organization_membership_id)
               )

      refute is_nil(id)
    end
  end

  describe "list_organization_memberships" do
    test "without any options, returns organization memberships and metadata", context do
      context
      |> ClientMock.list_organization_memberships()

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.OrganizationMembership{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_organization_memberships()
    end

    test "with the user_id option, forms the proper request to the API", context do
      opts = [user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context
      |> ClientMock.list_organization_memberships(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.OrganizationMembership{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_organization_memberships()
    end
  end

  describe "create_organization_membership" do
    test "with a valid payload, creates an organization membership", context do
      opts = [
        user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS",
        organization_id: "org_01EHT88Z8J8795GZNQ4ZP1J81T"
      ]

      context |> ClientMock.create_organization_membership(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.OrganizationMembership{id: id}} =
               WorkOS.UserManagement.create_organization_membership(opts |> Enum.into(%{}))

      refute is_nil(id)
    end
  end

  describe "delete_organization_membership" do
    test "sends a request to delete an organization membership", context do
      opts = [organization_membership_id: "om_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.delete_organization_membership(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.UserManagement.delete_organization_membership(
                 opts
                 |> Keyword.get(:organization_membership_id)
               )
    end
  end

  describe "list_invitations" do
    test "without any options, returns invitations and metadata", context do
      context
      |> ClientMock.list_invitations()

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.Invitation{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_invitations()
    end

    test "with the email option, forms the proper request to the API", context do
      opts = [email: "test@example.com"]

      context
      |> ClientMock.list_invitations(assert_fields: opts)

      assert {:ok,
              %WorkOS.List{
                data: [%WorkOS.UserManagement.Invitation{}],
                list_metadata: %{}
              }} = WorkOS.UserManagement.list_invitations()
    end
  end

  describe "get_invitation" do
    test "requests an invitation", context do
      opts = [invitation_id: "invitation_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.get_invitation(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Invitation{id: id}} =
               WorkOS.UserManagement.get_invitation(opts |> Keyword.get(:invitation_id))

      refute is_nil(id)
    end
  end

  describe "send_invitation" do
    test "with a valid payload, creates an invitation", context do
      opts = [email: "test@example.com"]

      context |> ClientMock.send_invitation(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Invitation{id: id}} =
               WorkOS.UserManagement.send_invitation(opts |> Enum.into(%{}))

      refute is_nil(id)
    end
  end

  describe "revoke_invitation" do
    test "with a valid payload, revokes an invitation", context do
      opts = [invitation_id: "invitation_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.revoke_invitation(assert_fields: opts)

      assert {:ok, %WorkOS.UserManagement.Invitation{id: id}} =
               WorkOS.UserManagement.revoke_invitation(opts |> Keyword.get(:invitation_id))

      refute is_nil(id)
    end
  end

  describe "WorkOS.UserManagement.MagicAuth.SendMagicAuthCode" do
    test "struct creation and cast" do
      code = %WorkOS.UserManagement.MagicAuth.SendMagicAuthCode{
        email: "test@example.com"
      }

      assert code.email == "test@example.com"

      casted =
        WorkOS.UserManagement.MagicAuth.SendMagicAuthCode.cast(%{"email" => "test@example.com"})

      assert %WorkOS.UserManagement.MagicAuth.SendMagicAuthCode{email: "test@example.com"} =
               casted
    end
  end

  describe "WorkOS.UserManagement.MultiFactor.AuthenticationChallenge" do
    test "struct creation and cast" do
      challenge = %WorkOS.UserManagement.MultiFactor.AuthenticationChallenge{
        id: "challenge_123",
        code: "123456",
        authentication_factor_id: "factor_123",
        expires_at: "2024-01-01T00:00:00Z",
        updated_at: "2024-01-01T00:00:00Z",
        created_at: "2024-01-01T00:00:00Z"
      }

      assert challenge.id == "challenge_123"
      assert challenge.code == "123456"
      assert challenge.authentication_factor_id == "factor_123"
      assert challenge.expires_at == "2024-01-01T00:00:00Z"
      assert challenge.updated_at == "2024-01-01T00:00:00Z"
      assert challenge.created_at == "2024-01-01T00:00:00Z"

      casted =
        WorkOS.UserManagement.MultiFactor.AuthenticationChallenge.cast(%{
          "id" => "challenge_123",
          "code" => "123456",
          "authentication_factor_id" => "factor_123",
          "expires_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z",
          "created_at" => "2024-01-01T00:00:00Z"
        })

      assert %WorkOS.UserManagement.MultiFactor.AuthenticationChallenge{
               id: "challenge_123",
               code: "123456"
             } = casted
    end
  end

  describe "WorkOS.UserManagement.MultiFactor.SMS" do
    test "struct creation and cast" do
      sms = %WorkOS.UserManagement.MultiFactor.SMS{phone_number: "+1234567890"}
      assert sms.phone_number == "+1234567890"

      casted = WorkOS.UserManagement.MultiFactor.SMS.cast(%{"phone_number" => "+1234567890"})
      assert %WorkOS.UserManagement.MultiFactor.SMS{phone_number: "+1234567890"} = casted
    end
  end

  describe "WorkOS.UserManagement.MultiFactor.TOTP" do
    test "struct creation and cast" do
      totp = %WorkOS.UserManagement.MultiFactor.TOTP{
        issuer: "WorkOS",
        user: "user@example.com",
        secret: "secret",
        qr_code: "qr_code",
        uri: "otpauth://totp/WorkOS:user@example.com?secret=secret"
      }

      assert totp.issuer == "WorkOS"
      assert totp.user == "user@example.com"
      assert totp.secret == "secret"
      assert totp.qr_code == "qr_code"
      assert totp.uri == "otpauth://totp/WorkOS:user@example.com?secret=secret"

      casted =
        WorkOS.UserManagement.MultiFactor.TOTP.cast(%{
          "issuer" => "WorkOS",
          "user" => "user@example.com",
          "secret" => "secret",
          "qr_code" => "qr_code",
          "uri" => "otpauth://totp/WorkOS:user@example.com?secret=secret"
        })

      assert %WorkOS.UserManagement.MultiFactor.TOTP{issuer: "WorkOS", user: "user@example.com"} =
               casted
    end
  end

  describe "WorkOS.UserManagement argument validation and error cases" do
    test "create_user/2 returns error when :email is missing" do
      assert_raise FunctionClauseError, fn ->
        WorkOS.UserManagement.create_user(%{})
      end
    end

    test "update_user/3 returns error when user_id is missing" do
      assert_raise Tesla.Mock.Error, fn ->
        WorkOS.UserManagement.update_user(nil, %{})
      end
    end

    test "get_authorization_url/1 returns error when required keys are missing" do
      assert {:error, _} = WorkOS.UserManagement.get_authorization_url(%{})
      assert {:error, _} = WorkOS.UserManagement.get_authorization_url(%{redirect_uri: "foo"})
    end

    test "create_user/2 propagates client error" do
      # Simulate WorkOS.Client.post returning error
      me = self()
      m = Module.concat([:TestClient])

      defmodule m do
        def post(_, _, _, _), do: {:error, :client_error}
        def request(_, _), do: {:error, :client_error}
      end

      client = %WorkOS.Client{api_key: "k", client_id: "c", base_url: "u", client: m}

      assert {:error, :client_error} =
               WorkOS.UserManagement.create_user(client, %{email: "foo@bar.com"})
    end

    test "get_user/2 propagates client error" do
      me = self()
      m = Module.concat([:TestClient2])

      defmodule m do
        def get(_, _, _, _), do: {:error, :client_error}
        def request(_, _), do: {:error, :client_error}
      end

      client = %WorkOS.Client{api_key: "k", client_id: "c", base_url: "u", client: m}
      assert {:error, :client_error} = WorkOS.UserManagement.get_user(client, "user_123")
    end
  end
end

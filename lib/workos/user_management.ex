defmodule WorkOS.UserManagement do
  @moduledoc """
  Manage User Management in WorkOS.

  @see https://workos.com/docs/reference/user-management
  """

  alias WorkOS.Empty
  alias WorkOS.UserManagement.Authentication
  alias WorkOS.UserManagement.EmailVerification.SendVerificationEmail
  alias WorkOS.UserManagement.EmailVerification.VerifyEmail
  alias WorkOS.UserManagement.Invitation
  alias WorkOS.UserManagement.MagicAuth.SendMagicAuthCode
  alias WorkOS.UserManagement.MultiFactor.AuthenticationFactor
  alias WorkOS.UserManagement.MultiFactor.EnrollAuthFactor
  alias WorkOS.UserManagement.OrganizationMembership
  alias WorkOS.UserManagement.ResetPassword
  alias WorkOS.UserManagement.User

  @doc """
  Generates an OAuth 2.0 authorization URL.

  Parameter options:

    * `:organization_id` - The `organization_id` connection selector is used to initiate SSO for an Organization.
    * `:connection_id` - The `connection_id` connection selector is used to initiate SSO for a Connection.
    * `:redirect_uri` - A Redirect URI to return an authorized user to. (required)
    * `:client_id` - This value can be obtained from the SSO Configuration page in the WorkOS dashboard.
    * `:provider` - The `provider` connection selector is used to initiate SSO using an OAuth-compatible provider.
    * `:state` - An optional parameter that can be used to encode arbitrary information to help restore application state between redirects.
    * `:login_hint` - Can be used to pre-fill the username/email address field of the IdP sign-in page for the user, if you know their username ahead of time.
    * `:domain_hint` - Can be used to pre-fill the domain field when initiating authentication with Microsoft OAuth, or with a GoogleSAML connection type.

  """
  @spec get_authorization_url(map()) :: {:ok, String.t()} | {:error, String.t()}
  def get_authorization_url(params)
      when is_map_key(params, :redirect_uri) and
             (is_map_key(params, :connection_id) or is_map_key(params, :organization_id) or
                is_map_key(params, :provider)) do
    client_id =
      params[:client_id] || WorkOS.client_id() ||
        raise "Missing required `client_id` parameter."

    defaults = %{
      client_id: client_id,
      response_type: "code"
    }

    query =
      defaults
      |> Map.merge(params)
      |> Map.take(
        [
          :client_id,
          :redirect_uri,
          :connection_id,
          :organization_id,
          :provider,
          :state,
          :login_hint,
          :domain_hint,
          :domain
        ] ++ Map.keys(defaults)
      )
      |> URI.encode_query()

    {:ok, "#{WorkOS.base_url()}/user_management/authorize?#{query}"}
  end

  def get_authorization_url(_params),
    do:
      {:error,
       "Incomplete arguments. Need to specify either a 'connection', 'organization', or 'provider'."}

  @doc """
  Gets a user.
  """
  @spec get_user(String.t()) :: WorkOS.Client.response(User.t())
  @spec get_user(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(User.t())
  def get_user(client \\ WorkOS.client(), user_id) do
    WorkOS.Client.get(client, User, "/user_management/users/:id",
      opts: [
        path_params: [id: user_id]
      ]
    )
  end

  @doc """
  Lists all users.

  Parameter options:

    * `:email` - Filter Users by their email.
    * `:organization_id` - Filter Users by the organization they are members of.
    * `:limit` - Maximum number of records to return. Accepts values between 1 and 100. Default is 10.
    * `:after` - Pagination cursor to receive records after a provided event ID.
    * `:before` - An object ID that defines your place in the list. When the ID is not present, you are at the end of the list.
    * `:order` - Order the results by the creation time. Supported values are "asc" and "desc" for showing older and newer records first respectively.

  """
  @spec list_users(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(WorkOS.List.t(User.t()))
  def list_users(client, opts) do
    WorkOS.Client.get(client, WorkOS.List.of(User), "/user_management/users",
      query: [
        email: opts[:email],
        organization_id: opts[:organization_id],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @spec list_users(map()) ::
          WorkOS.Client.response(WorkOS.List.t(User.t()))
  def list_users(opts \\ %{}) do
    WorkOS.Client.get(WorkOS.client(), WorkOS.List.of(User), "/user_management/users",
      query: [
        email: opts[:email],
        organization_id: opts[:organization_id],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @doc """
  Creates a user.

  Parameter options:

    * `:email` - The email address of the user. (required)
    * `:domains` - The password to set for the user.
    * `:first_name` - The user's first name.
    * `:last_name` - The user's last name.
    * `:email_verified` - Whether the user's email address was previously verified.

  """
  @spec create_user(map()) :: WorkOS.Client.response(User.t())
  @spec create_user(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(User.t())
  def create_user(client \\ WorkOS.client(), opts) when is_map_key(opts, :email) do
    WorkOS.Client.post(
      client,
      User,
      "/user_management/users",
      %{
        email: opts[:email],
        domains: opts[:domains],
        first_name: opts[:first_name],
        last_name: opts[:last_name],
        email_verified: opts[:email_verified]
      }
    )
  end

  @doc """
  Updates a user.

  Parameter options:

    * `:first_name` - The user's first name.
    * `:last_name` - The user's last name.
    * `:email_verified` - Whether the user's email address was previously verified.
    * `:password` - The password to set for the user.
    * `:password_hash` - The hashed password to set for the user, used when migrating from another user store. Mutually exclusive with password.
    * `:password_hash_type` - The algorithm originally used to hash the password, used when providing a password_hash. Valid values are `bcrypt`.

  """
  @spec update_user(String.t(), map()) :: WorkOS.Client.response(User.t())
  @spec update_user(WorkOS.Client.t(), String.t(), map()) ::
          WorkOS.Client.response(User.t())
  def update_user(client \\ WorkOS.client(), user_id, opts) do
    WorkOS.Client.put(client, User, "/user_management/users/#{user_id}", %{
      first_name: opts[:first_name],
      last_name: opts[:last_name],
      email_verified: !!opts[:email_verified],
      password: opts[:password],
      password_hash: opts[:password_hash],
      password_hash_type: opts[:password_hash_type]
    })
  end

  @doc """
  Deletes a user.
  """
  @spec delete_user(String.t()) :: WorkOS.Client.response(nil)
  @spec delete_user(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(nil)
  def delete_user(client \\ WorkOS.client(), user_id) do
    WorkOS.Client.delete(client, Empty, "/user_management/users/:id", %{},
      opts: [
        path_params: [id: user_id]
      ]
    )
  end

  @doc """
  Authenticates a user with password.

  Parameter options:

    * `:email` - The email address of the user. (required)
    * `:password` - The password of the user. (required)
    * `:ip_address` - The IP address of the request from the user who is attempting to authenticate.
    * `:user_agent` - The user agent of the request from the user who is attempting to authenticate. This should be the value of the User-Agent header.

  """
  @spec authenticate_with_password(map()) ::
          WorkOS.Client.response(Authentication.t())
  @spec authenticate_with_password(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Authentication.t())
  def authenticate_with_password(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :email) and
             is_map_key(opts, :password) do
    WorkOS.Client.post(
      client,
      Authentication,
      "/user_management/authenticate",
      %{
        client_id: WorkOS.client_id(client),
        client_secret: WorkOS.api_key(client),
        grant_type: "password",
        email: opts[:email],
        password: opts[:password],
        ip_address: opts[:ip_address],
        user_agent: opts[:user_agent]
      }
    )
  end

  @doc """
  Authenticates an OAuth or SSO User.

  Parameter options:

    * `:code` - The authorization value which was passed back as a query parameter in the callback to the Redirect URI. (required)
    * `:ip_address` - The IP address of the request from the user who is attempting to authenticate.
    * `:user_agent` - The user agent of the request from the user who is attempting to authenticate. This should be the value of the User-Agent header.

  """
  @spec authenticate_with_code(map()) ::
          WorkOS.Client.response(Authentication.t())
  @spec authenticate_with_code(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Authentication.t())
  def authenticate_with_code(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :code) do
    WorkOS.Client.post(
      client,
      Authentication,
      "/user_management/authenticate",
      %{
        client_id: WorkOS.client_id(client),
        client_secret: WorkOS.api_key(client),
        grant_type: "authorization_code",
        code: opts[:code],
        ip_address: opts[:ip_address],
        user_agent: opts[:user_agent]
      }
    )
  end

  @doc """
  Authenticates with Magic Auth.

  Parameter options:

    * `:code` - The one-time code that was emailed to the user. (required)
    * `:email` - The email the User who will be authenticated. (required)
    * `:link_authorization_code` - An authorization code used in a previous authenticate request that resulted in an existing user error response.
    * `:ip_address` - The IP address of the request from the user who is attempting to authenticate.
    * `:user_agent` - The user agent of the request from the user who is attempting to authenticate. This should be the value of the User-Agent header.

  """
  @spec authenticate_with_magic_auth(map()) ::
          WorkOS.Client.response(Authentication.t())
  @spec authenticate_with_magic_auth(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Authentication.t())
  def authenticate_with_magic_auth(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :code) and
             is_map_key(opts, :email) do
    WorkOS.Client.post(
      client,
      Authentication,
      "/user_management/authenticate",
      %{
        client_id: WorkOS.client_id(client),
        client_secret: WorkOS.api_key(client),
        grant_type: "urn:workos:oauth:grant-type:magic-auth:code",
        code: opts[:code],
        email: opts[:email],
        link_authorization_code: opts[:link_authorization_code],
        ip_address: opts[:ip_address],
        user_agent: opts[:user_agent]
      }
    )
  end

  @doc """
  Authenticates with Email Verification Code

  Parameter options:

    * `:code` - The one-time code that was emailed to the user. (required)
    * `:pending_authentication_code` - The pending_authentication_token returned from an authentication attempt due to an unverified email address. (required)
    * `:ip_address` - The IP address of the request from the user who is attempting to authenticate.
    * `:user_agent` - The user agent of the request from the user who is attempting to authenticate. This should be the value of the User-Agent header.

  """
  @spec authenticate_with_email_verification(map()) ::
          WorkOS.Client.response(Authentication.t())
  @spec authenticate_with_email_verification(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Authentication.t())
  def authenticate_with_email_verification(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :code) and
             is_map_key(opts, :pending_authentication_code) do
    WorkOS.Client.post(
      client,
      Authentication,
      "/user_management/authenticate",
      %{
        client_id: WorkOS.client_id(client),
        client_secret: WorkOS.api_key(client),
        grant_type: "urn:workos:oauth:grant-type:email-verification:code",
        code: opts[:code],
        pending_authentication_code: opts[:pending_authentication_code],
        ip_address: opts[:ip_address],
        user_agent: opts[:user_agent]
      }
    )
  end

  @doc """
  Authenticates with MFA TOTP

  Parameter options:

    * `:code` - The time-based-one-time-password generated by the Factor that was challenged. (required)
    * `:authentication_challenge_id` - The unique ID of the authentication Challenge created for the TOTP Factor for which the user is enrolled. (required)
    * `:pending_authentication_code` - The token returned from a failed authentication attempt due to MFA challenge. (required)
    * `:ip_address` - The IP address of the request from the user who is attempting to authenticate.
    * `:user_agent` - The user agent of the request from the user who is attempting to authenticate. This should be the value of the User-Agent header.

  """
  @spec authenticate_with_totp(map()) ::
          WorkOS.Client.response(Authentication.t())
  @spec authenticate_with_totp(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Authentication.t())
  def authenticate_with_totp(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :code) and
             is_map_key(opts, :authentication_challenge_id) and
             is_map_key(opts, :pending_authentication_code) do
    WorkOS.Client.post(
      client,
      Authentication,
      "/user_management/authenticate",
      %{
        client_id: WorkOS.client_id(client),
        client_secret: WorkOS.api_key(client),
        grant_type: "urn:workos:oauth:grant-type:mfa-totp",
        code: opts[:code],
        authentication_challenge_id: opts[:authentication_challenge_id],
        pending_authentication_code: opts[:pending_authentication_code],
        ip_address: opts[:ip_address],
        user_agent: opts[:user_agent]
      }
    )
  end

  @doc """
  Authenticates with Selected Organization

  Parameter options:

    * `:pending_authentication_code` - The token returned from a failed authentication attempt due to organization selection being required. (required)
    * `:organization_id` - The Organization ID the user selected. (required)
    * `:ip_address` - The IP address of the request from the user who is attempting to authenticate.
    * `:user_agent` - The user agent of the request from the user who is attempting to authenticate. This should be the value of the User-Agent header.

  """
  @spec authenticate_with_selected_organization(map()) ::
          WorkOS.Client.response(Authentication.t())
  @spec authenticate_with_selected_organization(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Authentication.t())
  def authenticate_with_selected_organization(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :pending_authentication_code) and
             is_map_key(opts, :organization_id) do
    WorkOS.Client.post(
      client,
      Authentication,
      "/user_management/authenticate",
      %{
        client_id: WorkOS.client_id(client),
        client_secret: WorkOS.api_key(client),
        grant_type: "urn:workos:oauth:grant-type:organization-selection",
        pending_authentication_code: opts[:pending_authentication_code],
        organization_id: opts[:organization_id],
        ip_address: opts[:ip_address],
        user_agent: opts[:user_agent]
      }
    )
  end

  @doc """
  Creates a one-time Magic Auth code.

  Parameter options:

    * `:email` - The email address the one-time code will be sent to. (required)

  """
  @spec send_magic_auth_code(String.t()) :: WorkOS.Client.response(SendMagicAuthCode.t())
  @spec send_magic_auth_code(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(SendMagicAuthCode.t())
  def send_magic_auth_code(client \\ WorkOS.client(), email) do
    case WorkOS.Client.post(
           client,
           Empty,
           "/user_management/magic_auth/send",
           %{
             email: email
           }
         ) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Enrolls a user in a new Factor.

  Parameter options:

    * `:type` - The type of the factor to enroll. Only option available is `totp`. (required)
    * `:totp_issuer` - For `totp` factors. Typically your application or company name, this helps users distinguish between factors in authenticator apps.
    * `:totp_user` - For `totp` factors. Used as the account name in authenticator apps. Defaults to the user's email.

  """
  @spec enroll_auth_factor(String.t(), map()) :: WorkOS.Client.response(EnrollAuthFactor.t())
  @spec enroll_auth_factor(WorkOS.Client.t(), String.t(), map()) ::
          WorkOS.Client.response(EnrollAuthFactor.t())
  def enroll_auth_factor(client \\ WorkOS.client(), user_id, opts) when is_map_key(opts, :type) do
    WorkOS.Client.post(
      client,
      EnrollAuthFactor,
      "/user_management/users/:id/auth_factors",
      %{
        type: opts[:type],
        totp_issuer: opts[:totp_issuer],
        totp_user: opts[:totp_user]
      },
      opts: [
        path_params: [id: user_id]
      ]
    )
  end

  @doc """
  Lists all auth factors of a user.
  """
  @spec list_auth_factors(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(WorkOS.List.t(AuthenticationFactor.t()))
  def list_auth_factors(client \\ WorkOS.client(), user_id) do
    WorkOS.Client.get(
      client,
      WorkOS.List.of(AuthenticationFactor),
      "/user_management/users/:id/auth_factors",
      opts: [
        path_params: [id: user_id]
      ]
    )
  end

  @doc """
  Sends verification email.
  """
  @spec send_verification_email(String.t()) :: WorkOS.Client.response(SendVerificationEmail.t())
  @spec send_verification_email(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(SendVerificationEmail.t())
  def send_verification_email(client \\ WorkOS.client(), user_id) do
    WorkOS.Client.post(
      client,
      SendVerificationEmail,
      "/user_management/users/:id/email_verification/send",
      %{},
      opts: [
        path_params: [id: user_id]
      ]
    )
  end

  @doc """
  Verifies user email.

  Parameter options:

    * `:code` - The one-time code emailed to the user. (required)

  """
  @spec verify_email(String.t(), map()) :: WorkOS.Client.response(VerifyEmail.t())
  @spec verify_email(WorkOS.Client.t(), String.t(), map()) ::
          WorkOS.Client.response(VerifyEmail.t())
  def verify_email(client \\ WorkOS.client(), user_id, opts) when is_map_key(opts, :code) do
    WorkOS.Client.post(
      client,
      VerifyEmail,
      "/user_management/users/:id/email_verification/confirm",
      %{
        code: opts[:code]
      },
      opts: [
        path_params: [id: user_id]
      ]
    )
  end

  @doc """
  Sends a password reset email to a user.

  Parameter options:

    * `:email` - The email of the user that wishes to reset their password. (required)
    * `:password_reset_url` - The password to set for the user. (required)

  """
  @spec send_password_reset_email(map()) :: WorkOS.Client.response(OrganizationMembership.t())
  @spec send_password_reset_email(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(OrganizationMembership.t())
  def send_password_reset_email(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :email) and is_map_key(opts, :password_reset_url) do
    case WorkOS.Client.post(client, Empty, "/user_management/password_reset/send", %{
           email: opts[:email],
           password_reset_url: opts[:password_reset_url]
         }) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resets password.

  Parameter options:

    * `:token` - The reset token emailed to the user. (required)
    * `:new_password` - The new password to be set for the user. (required)

  """
  @spec reset_password(map()) :: WorkOS.Client.response(ResetPassword.t())
  @spec reset_password(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(ResetPassword.t())
  def reset_password(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :token) and is_map_key(opts, :new_password) do
    WorkOS.Client.post(
      client,
      ResetPassword,
      "/user_management/password_reset/confirm",
      %{
        token: opts[:token],
        new_password: opts[:new_password]
      }
    )
  end

  @doc """
  Gets an organization membership.
  """
  @spec get_organization_membership(String.t()) ::
          WorkOS.Client.response(OrganizationMembership.t())
  @spec get_organization_membership(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(OrganizationMembership.t())
  def get_organization_membership(client \\ WorkOS.client(), organization_membership_id) do
    WorkOS.Client.get(
      client,
      OrganizationMembership,
      "/user_management/organization_memberships/:id",
      opts: [
        path_params: [id: organization_membership_id]
      ]
    )
  end

  @doc """
  Lists all organization memberships.

  Parameter options:

    * `:user_id` - The ID of the User.
    * `:organization_id` - The ID of the Organization to which the user belongs to.
    * `:limit` - Maximum number of records to return. Accepts values between 1 and 100. Default is 10.
    * `:after` - Pagination cursor to receive records after a provided event ID.
    * `:before` - An object ID that defines your place in the list. When the ID is not present, you are at the end of the list.
    * `:order` - Order the results by the creation time. Supported values are "asc" and "desc" for showing older and newer records first respectively.

  """
  @spec list_organization_memberships(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(WorkOS.List.t(OrganizationMembership.t()))
  def list_organization_memberships(client, opts) do
    WorkOS.Client.get(
      client,
      WorkOS.List.of(OrganizationMembership),
      "/user_management/organization_memberships",
      query: [
        user_id: opts[:user_id],
        organization_id: opts[:organization_id],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @spec list_organization_memberships(map()) ::
          WorkOS.Client.response(WorkOS.List.t(OrganizationMembership.t()))
  def list_organization_memberships(opts \\ %{}) do
    WorkOS.Client.get(
      WorkOS.client(),
      WorkOS.List.of(OrganizationMembership),
      "/user_management/organization_memberships",
      query: [
        user_id: opts[:user_id],
        organization_id: opts[:organization_id],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @doc """
  Creates an organization membership.

  Parameter options:

    * `:user_id` - The ID of the User. (required)
    * `:organization_id` - The ID of the Organization to which the user belongs to. (required)

  """
  @spec create_organization_membership(map()) ::
          WorkOS.Client.response(OrganizationMembership.t())
  @spec create_organization_membership(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(OrganizationMembership.t())
  def create_organization_membership(client \\ WorkOS.client(), opts)
      when is_map_key(opts, :user_id) and is_map_key(opts, :organization_id) do
    WorkOS.Client.post(
      client,
      OrganizationMembership,
      "/user_management/organization_memberships",
      %{
        user_id: opts[:user_id],
        organization_id: opts[:organization_id]
      }
    )
  end

  @doc """
  Deletes an organization membership.
  """
  @spec delete_organization_membership(String.t()) :: WorkOS.Client.response(nil)
  @spec delete_organization_membership(WorkOS.Client.t(), String.t()) ::
          WorkOS.Client.response(nil)
  def delete_organization_membership(client \\ WorkOS.client(), organization_membership_id) do
    WorkOS.Client.delete(client, Empty, "/user_management/organization_memberships/:id", %{},
      opts: [
        path_params: [id: organization_membership_id]
      ]
    )
  end

  @doc """
  Gets an invitation.
  """
  @spec get_invitation(String.t()) :: WorkOS.Client.response(Invitation.t())
  @spec get_invitation(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(Invitation.t())
  def get_invitation(client \\ WorkOS.client(), invitation_id) do
    WorkOS.Client.get(client, Invitation, "/user_management/invitations/:id",
      opts: [
        path_params: [id: invitation_id]
      ]
    )
  end

  @doc """
  Lists all invitations.

  Parameter options:

    * `:email` - The email address of a recipient.
    * `:organization_id` - The ID of the Organization that the recipient was invited to join.
    * `:limit` - Maximum number of records to return. Accepts values between 1 and 100. Default is 10.
    * `:after` - Pagination cursor to receive records after a provided event ID.
    * `:before` - An object ID that defines your place in the list. When the ID is not present, you are at the end of the list.
    * `:order` - Order the results by the creation time. Supported values are "asc" and "desc" for showing older and newer records first respectively.

  """
  @spec list_invitations(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(WorkOS.List.t(Invitation.t()))
  def list_invitations(client, opts) do
    WorkOS.Client.get(client, WorkOS.List.of(Invitation), "/user_management/invitations",
      query: [
        email: opts[:email],
        organization_id: opts[:organization_id],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @spec list_invitations(map()) ::
          WorkOS.Client.response(WorkOS.List.t(Invitation.t()))
  def list_invitations(opts \\ %{}) do
    WorkOS.Client.get(WorkOS.client(), WorkOS.List.of(Invitation), "/user_management/invitations",
      query: [
        email: opts[:email],
        organization_id: opts[:organization_id],
        limit: opts[:limit],
        after: opts[:after],
        before: opts[:before],
        order: opts[:order]
      ]
    )
  end

  @doc """
  Sends an invitation.

  Parameter options:

    * `:email` - The email address of the recipient. (required)
    * `:organization_id` - The ID of the Organization to which the recipient is being invited.
    * `:expires_in_days` - The number of days the invitations will be valid for.
    * `:inviter_user_id` - The ID of the User sending the invitation.

  """
  @spec send_invitation(map()) :: WorkOS.Client.response(Invitation.t())
  @spec send_invitation(WorkOS.Client.t(), map()) ::
          WorkOS.Client.response(Invitation.t())
  def send_invitation(client \\ WorkOS.client(), opts) when is_map_key(opts, :email) do
    WorkOS.Client.post(
      client,
      Invitation,
      "/user_management/invitations",
      %{
        email: opts[:email],
        organization_id: opts[:organization_id],
        expires_in_days: opts[:expires_in_days],
        inviter_user_id: opts[:inviter_user_id]
      }
    )
  end

  @doc """
  Revokes an invitation.
  """
  @spec revoke_invitation(String.t()) :: WorkOS.Client.response(Invitation.t())
  @spec revoke_invitation(WorkOS.Client.t(), String.t()) :: WorkOS.Client.response(Invitation.t())
  def revoke_invitation(client \\ WorkOS.client(), invitation_id) do
    WorkOS.Client.post(client, Invitation, "/user_management/invitations/:id/revoke", %{},
      opts: [
        path_params: [id: invitation_id]
      ]
    )
  end
end

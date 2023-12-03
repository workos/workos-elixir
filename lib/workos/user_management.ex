defmodule WorkOS.UserManagement do
  @moduledoc """
  Manage User Management in WorkOS.

  @see https://workos.com/docs/reference/user-management
  """

  alias WorkOS.Empty
  alias WorkOS.UserManagement.User
  alias WorkOS.UserManagement.Invitation
  alias WorkOS.UserManagement.OrganizationMembership
  alias WorkOS.UserManagement.ResetPassword

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
      opts: [
        query: %{
          email: opts[:email],
          organization_id: opts[:organization_id],
          limit: opts[:limit],
          after: opts[:after],
          before: opts[:before],
          order: opts[:order]
        }
      ]
    )
  end

  @spec list_users(map()) ::
          WorkOS.Client.response(WorkOS.List.t(User.t()))
  def list_users(opts \\ %{}) do
    WorkOS.Client.get(WorkOS.client(), WorkOS.List.of(User), "/user_management/users",
      opts: [
        query: %{
          email: opts[:email],
          organization_id: opts[:organization_id],
          limit: opts[:limit],
          after: opts[:after],
          before: opts[:before],
          order: opts[:order]
        }
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
    case WorkOS.Client.post(client, User, "/user_management/password_reset/send", %{
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
      opts: [
        query: %{
          user_id: opts[:user_id],
          organization_id: opts[:organization_id],
          limit: opts[:limit],
          after: opts[:after],
          before: opts[:before],
          order: opts[:order]
        }
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
      opts: [
        query: %{
          user_id: opts[:user_id],
          organization_id: opts[:organization_id],
          limit: opts[:limit],
          after: opts[:after],
          before: opts[:before],
          order: opts[:order]
        }
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
      opts: [
        query: %{
          email: opts[:email],
          organization_id: opts[:organization_id],
          limit: opts[:limit],
          after: opts[:after],
          before: opts[:before],
          order: opts[:order]
        }
      ]
    )
  end

  @spec list_invitations(map()) ::
          WorkOS.Client.response(WorkOS.List.t(Invitation.t()))
  def list_invitations(opts \\ %{}) do
    WorkOS.Client.get(WorkOS.client(), WorkOS.List.of(Invitation), "/user_management/invitations",
      opts: [
        query: %{
          email: opts[:email],
          organization_id: opts[:organization_id],
          limit: opts[:limit],
          after: opts[:after],
          before: opts[:before],
          order: opts[:order]
        }
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

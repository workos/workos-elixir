defmodule WorkOS.UserManagementTest do
  use WorkOS.TestCase

  alias WorkOS.UserManagement.ClientMock

  setup :setup_env

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
  end

  describe "delete_user" do
    test "sends a request to delete a user", context do
      opts = [user_id: "user_01H5JQDV7R7ATEYZDEG0W5PRYS"]

      context |> ClientMock.delete_user(assert_fields: opts)

      assert {:ok, %WorkOS.Empty{}} =
               WorkOS.UserManagement.delete_user(opts |> Keyword.get(:user_id))
    end
  end

  describe "send_password_reset_email" do
    test "with a valid payload, sends password reset email", context do
      opts = [
        email: "test@example.com",
        password_reset_url: "https://reset-password-test.com"
      ]

      context |> ClientMock.send_password_reset_email(assert_fields: opts)

      assert :ok =
               WorkOS.UserManagement.send_password_reset_email(opts |> Enum.into(%{}))
    end
  end

  @tag :single
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
end

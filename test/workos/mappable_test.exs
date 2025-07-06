defmodule WorkOS.MappableTest do
  use ExUnit.Case, async: true

  alias WorkOS.Mappable
  alias WorkOS.UserManagement.User
  alias WorkOS.UserManagement.ResetPassword

  describe "User struct to_map/1" do
    test "converts User struct to map" do
      user = %User{
        id: "user_123",
        email: "john@example.com",
        email_verified: true,
        first_name: "John",
        last_name: "Doe",
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      expected_map = %{
        id: "user_123",
        email: "john@example.com",
        email_verified: true,
        first_name: "John",
        last_name: "Doe",
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      assert User.to_map(user) == expected_map
    end

    test "converts User struct to map using protocol" do
      user = %User{
        id: "user_123",
        email: "john@example.com",
        email_verified: true,
        first_name: "John",
        last_name: "Doe",
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      expected_map = %{
        id: "user_123",
        email: "john@example.com",
        email_verified: true,
        first_name: "John",
        last_name: "Doe",
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      assert Mappable.to_map(user) == expected_map
    end

    test "handles nil values in User struct" do
      user = %User{
        id: "user_123",
        email: "john@example.com",
        email_verified: false,
        first_name: nil,
        last_name: nil,
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      expected_map = %{
        id: "user_123",
        email: "john@example.com",
        email_verified: false,
        first_name: nil,
        last_name: nil,
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      assert User.to_map(user) == expected_map
    end
  end

  describe "ResetPassword struct to_map/1" do
    test "converts ResetPassword struct to map" do
      user = %User{
        id: "user_123",
        email: "john@example.com",
        email_verified: true,
        first_name: "John",
        last_name: "Doe",
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      reset_password = %ResetPassword{
        user: user
      }

      expected_map = %{
        user: user
      }

      assert ResetPassword.to_map(reset_password) == expected_map
    end

    test "converts ResetPassword struct to map using protocol" do
      user = %User{
        id: "user_123",
        email: "john@example.com",
        email_verified: true,
        first_name: "John",
        last_name: "Doe",
        updated_at: "2023-01-01T00:00:00Z",
        created_at: "2023-01-01T00:00:00Z"
      }

      reset_password = %ResetPassword{
        user: user
      }

      expected_map = %{
        user: user
      }

      assert Mappable.to_map(reset_password) == expected_map
    end
  end

  describe "to_map_list/1" do
    test "converts list of User structs to list of maps" do
      users = [
        %User{
          id: "user_123",
          email: "john@example.com",
          email_verified: true,
          first_name: "John",
          last_name: "Doe",
          updated_at: "2023-01-01T00:00:00Z",
          created_at: "2023-01-01T00:00:00Z"
        },
        %User{
          id: "user_456",
          email: "jane@example.com",
          email_verified: false,
          first_name: "Jane",
          last_name: "Smith",
          updated_at: "2023-01-02T00:00:00Z",
          created_at: "2023-01-02T00:00:00Z"
        }
      ]

      expected_maps = [
        %{
          id: "user_123",
          email: "john@example.com",
          email_verified: true,
          first_name: "John",
          last_name: "Doe",
          updated_at: "2023-01-01T00:00:00Z",
          created_at: "2023-01-01T00:00:00Z"
        },
        %{
          id: "user_456",
          email: "jane@example.com",
          email_verified: false,
          first_name: "Jane",
          last_name: "Smith",
          updated_at: "2023-01-02T00:00:00Z",
          created_at: "2023-01-02T00:00:00Z"
        }
      ]

      assert Mappable.to_map_list(users) == expected_maps
    end

    test "returns nil when given nil" do
      assert Mappable.to_map_list(nil) == nil
    end

    test "returns empty list when given empty list" do
      assert Mappable.to_map_list([]) == []
    end
  end
end

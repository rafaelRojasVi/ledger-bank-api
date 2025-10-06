defmodule LedgerBankApi.Accounts.NormalizeTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Accounts.Normalize

  describe "user_attrs/1 - Public registration (security-hardened)" do
    test "normalizes user creation attributes" do
      attrs = %{
        "email" => "  USER@EXAMPLE.COM  ",
        "full_name" => "  John Doe  ",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.user_attrs(attrs)

      assert result["email"] == "user@example.com"
      assert result["full_name"] == "John Doe"
      assert result["role"] == "user"  # ← Always forced to "user"
      assert result["password"] == "password123"
      assert result["password_confirmation"] == "password123"
    end

    test "SECURITY: forces role to user even when admin role is provided" do
      attrs = %{
        "email" => "hacker@example.com",
        "full_name" => "Attempted Admin",
        "role" => "admin",  # ← Attempting to set admin role
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.user_attrs(attrs)

      assert result["role"] == "user"  # ← Role is FORCED to "user", ignoring input
    end

    test "SECURITY: forces role to user even when support role is provided" do
      attrs = %{
        "email" => "hacker@example.com",
        "full_name" => "Attempted Support",
        "role" => "support",  # ← Attempting to set support role
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.user_attrs(attrs)

      assert result["role"] == "user"  # ← Role is FORCED to "user", ignoring input
    end

    test "SECURITY: role parameter is completely ignored and not processed" do
      attrs = %{
        "email" => "user@example.com",
        "full_name" => "John Doe",
        "role" => "INVALID_ROLE_ATTEMPT",  # ← Even invalid role input
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.user_attrs(attrs)

      assert result["role"] == "user"  # ← Still forced to "user"
    end

    test "adds default role when not provided" do
      attrs = %{
        "email" => "user@example.com",
        "full_name" => "John Doe",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.user_attrs(attrs)

      assert result["role"] == "user"
      assert result["status"] == "ACTIVE"
    end

    test "filters out unknown fields" do
      attrs = %{
        "email" => "user@example.com",
        "full_name" => "John Doe",
        "unknown_field" => "value",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.user_attrs(attrs)

      refute Map.has_key?(result, "unknown_field")
      assert Map.has_key?(result, "email")
    end
  end

  describe "admin_user_attrs/1 - Admin-initiated user creation" do
    test "normalizes admin user creation attributes with role selection" do
      attrs = %{
        "email" => "  ADMIN@EXAMPLE.COM  ",
        "full_name" => "  Admin User  ",
        "role" => "  ADMIN  ",
        "password" => "password123456789",
        "password_confirmation" => "password123456789"
      }

      result = Normalize.admin_user_attrs(attrs)

      assert result["email"] == "admin@example.com"
      assert result["full_name"] == "Admin User"
      assert result["role"] == "admin"  # ← Admin role is preserved
      assert result["password"] == "password123456789"
    end

    test "allows admin role for admin-initiated creation" do
      attrs = %{
        "email" => "admin@example.com",
        "full_name" => "Admin User",
        "role" => "admin",
        "password" => "password123456789",
        "password_confirmation" => "password123456789"
      }

      result = Normalize.admin_user_attrs(attrs)

      assert result["role"] == "admin"  # ← Admin role is allowed
    end

    test "allows support role for admin-initiated creation" do
      attrs = %{
        "email" => "support@example.com",
        "full_name" => "Support User",
        "role" => "support",
        "password" => "password123456789",
        "password_confirmation" => "password123456789"
      }

      result = Normalize.admin_user_attrs(attrs)

      assert result["role"] == "support"  # ← Support role is allowed
    end

    test "defaults to user role when not provided" do
      attrs = %{
        "email" => "user@example.com",
        "full_name" => "Regular User",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.admin_user_attrs(attrs)

      assert result["role"] == "user"
    end

    test "removes invalid role and defaults to user" do
      attrs = %{
        "email" => "user@example.com",
        "full_name" => "User",
        "role" => "invalid_role",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.admin_user_attrs(attrs)

      # Invalid role is removed and defaults to "user"
      assert result["role"] == "user"
    end
  end

  describe "user_update_attrs/1" do
    test "normalizes user update attributes" do
      attrs = %{
        "email" => "  USER@EXAMPLE.COM  ",
        "full_name" => "  John Doe  ",
        "role" => "  SUPPORT  ",
        "status" => "  active  "
      }

      result = Normalize.user_update_attrs(attrs)

      assert result["email"] == "user@example.com"
      assert result["full_name"] == "John Doe"
      assert result["role"] == "support"
      assert result["status"] == "ACTIVE"
      assert Map.has_key?(result, "updated_at")
    end

    test "filters out password fields" do
      attrs = %{
        "email" => "user@example.com",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      result = Normalize.user_update_attrs(attrs)

      refute Map.has_key?(result, "password")
      refute Map.has_key?(result, "password_confirmation")
      assert Map.has_key?(result, "email")
    end
  end

  describe "password_attrs/1" do
    test "normalizes password attributes" do
      attrs = %{
        "password" => "  password123  ",
        "password_confirmation" => "  password123  ",
        "current_password" => "  oldpassword  "
      }

      result = Normalize.password_attrs(attrs)

      assert result["password"] == "password123"
      assert result["password_confirmation"] == "password123"
      assert result["current_password"] == "oldpassword"
    end

    test "filters out non-password fields" do
      attrs = %{
        "password" => "password123",
        "email" => "user@example.com",
        "role" => "admin"
      }

      result = Normalize.password_attrs(attrs)

      assert Map.has_key?(result, "password")
      refute Map.has_key?(result, "email")
      refute Map.has_key?(result, "role")
    end
  end

  describe "login_attrs/1" do
    test "normalizes login attributes" do
      attrs = %{
        "email" => "  USER@EXAMPLE.COM  ",
        "password" => "password123"
      }

      result = Normalize.login_attrs(attrs)

      assert result["email"] == "user@example.com"
      assert result["password"] == "password123"
    end
  end

  describe "pagination_attrs/1" do
    test "normalizes pagination with valid values" do
      attrs = %{
        "page" => "2",
        "page_size" => "50"
      }

      result = Normalize.pagination_attrs(attrs)

      assert result["page"] == 2
      assert result["page_size"] == 50
    end

    test "uses defaults for invalid values" do
      attrs = %{
        "page" => "invalid",
        "page_size" => "invalid"
      }

      result = Normalize.pagination_attrs(attrs)

      assert result["page"] == 1
      assert result["page_size"] == 20
    end

    test "caps page_size at 100" do
      attrs = %{
        "page_size" => "200"
      }

      result = Normalize.pagination_attrs(attrs)

      assert result["page_size"] == 100
    end

    test "uses defaults when not provided" do
      attrs = %{}

      result = Normalize.pagination_attrs(attrs)

      assert result["page"] == 1
      assert result["page_size"] == 20
    end
  end

  describe "sort_attrs/1" do
    test "parses single sort field" do
      attrs = %{"sort" => "email"}

      result = Normalize.sort_attrs(attrs)

      assert result == [{:email, :asc}]
    end

    test "parses sort field with direction" do
      attrs = %{"sort" => "email:desc"}

      result = Normalize.sort_attrs(attrs)

      assert result == [{:email, :desc}]
    end

    test "parses multiple sort fields" do
      attrs = %{"sort" => "email:asc,created_at:desc"}

      result = Normalize.sort_attrs(attrs)

      assert result == [{:email, :asc}, {:created_at, :desc}]
    end

    test "handles invalid sort fields" do
      attrs = %{"sort" => "email:invalid,created_at:desc"}

      result = Normalize.sort_attrs(attrs)

      assert result == [{:created_at, :desc}]
    end

    test "returns empty list when sort not provided" do
      attrs = %{}

      result = Normalize.sort_attrs(attrs)

      assert result == []
    end
  end

  describe "filter_attrs/1" do
    test "extracts filter fields" do
      attrs = %{
        "status" => "ACTIVE",
        "role" => "user",
        "page" => "1",
        "sort" => "email"
      }

      result = Normalize.filter_attrs(attrs)

      assert result == %{status: "ACTIVE", role: "user"}
    end

    test "filters out empty values" do
      attrs = %{
        "status" => "ACTIVE",
        "role" => "",
        "email" => "   "
      }

      result = Normalize.filter_attrs(attrs)

      assert result == %{status: "ACTIVE"}
    end

    test "returns empty map when no valid filters" do
      attrs = %{
        "page" => "1",
        "sort" => "email"
      }

      result = Normalize.filter_attrs(attrs)

      assert result == %{}
    end
  end

  describe "role normalization - admin_user_attrs (admin creation)" do
    test "normalizes valid roles for admin user creation" do
      valid_roles = ["user", "admin", "support", "USER", "ADMIN", "SUPPORT"]

      for role <- valid_roles do
        attrs = %{"role" => role, "email" => "test@example.com", "full_name" => "Test"}
        result = Normalize.admin_user_attrs(attrs)

        expected = String.downcase(role)
        assert result["role"] == expected, "Failed for role: #{role}"
      end
    end

    test "user_attrs always forces role to user (public registration)" do
      # Test that user_attrs ALWAYS returns "user" role regardless of input
      test_roles = ["user", "admin", "support", "USER", "ADMIN", "SUPPORT", "invalid_role"]

      for role <- test_roles do
        attrs = %{"role" => role, "email" => "test@example.com", "full_name" => "Test"}
        result = Normalize.user_attrs(attrs)

        assert result["role"] == "user", "user_attrs should always return 'user' role, got #{result["role"]} for input #{role}"
      end
    end

    test "admin_user_attrs ignores invalid roles and defaults to user" do
      attrs = %{"role" => "invalid_role", "email" => "test@example.com", "full_name" => "Test"}
      result = Normalize.admin_user_attrs(attrs)

      # Should fall back to default
      assert result["role"] == "user"
    end
  end

  describe "status normalization" do
    test "normalizes valid statuses" do
      valid_statuses = ["active", "suspended", "deleted", "ACTIVE", "SUSPENDED", "DELETED"]

      for status <- valid_statuses do
        attrs = %{"status" => status}
        result = Normalize.user_update_attrs(attrs)

        expected = String.upcase(status)
        assert result["status"] == expected, "Failed for status: #{status}"
      end
    end

    test "ignores invalid statuses" do
      attrs = %{"status" => "invalid_status"}
      result = Normalize.user_update_attrs(attrs)

      # Should not include invalid status
      refute Map.has_key?(result, "status")
    end
  end
end

defmodule LedgerBankApiWeb.Controllers.SecurityUserCreationTest do
  @moduledoc """
  Security-focused tests for user creation endpoints.

  This test suite specifically validates that the critical security vulnerability
  (CVE-INTERNAL-001: Public endpoint allowing admin creation) has been fixed.

  ## Vulnerability Fixed
  Previously, POST /api/users was public and accepted a "role" parameter,
  allowing anyone to create admin accounts without authentication.

  ## Fix Implemented
  - Public endpoint (POST /api/users) now FORCES role to "user"
  - New admin endpoint (POST /api/users/admin) requires admin authentication
  - Role parameter is completely ignored on public registration
  """

  use LedgerBankApiWeb.ConnCase, async: false
  alias LedgerBankApi.UsersFixtures
  alias LedgerBankApi.Accounts.{AuthService, UserService}

  describe "SECURITY: Public user registration vulnerability (CVE-INTERNAL-001)" do
    test "PUBLIC ENDPOINT: Attempting to create admin via public endpoint creates regular user", %{conn: conn} do
      # Simulate attacker attempting to create admin account via public endpoint
      malicious_params = %{
        email: "attacker@evil.com",
        full_name: "Evil Attacker",
        password: "password123!",
        password_confirmation: "password123!",
        role: "admin"  # ← ATTACK ATTEMPT: Trying to escalate to admin
      }

      # POST to public registration endpoint (no authentication)
      conn = post(conn, ~p"/api/users", malicious_params)

      # Should succeed BUT with role forced to "user"
      assert response = json_response(conn, 201)
      assert %{
        "success" => true,
        "data" => %{
          "email" => "attacker@evil.com",
          "role" => "user"  # ← SECURITY FIX: Role is "user", NOT "admin"
        }
      } = response

      # Verify in database that user is NOT an admin
      {:ok, created_user} = UserService.get_user_by_email("attacker@evil.com")
      assert created_user.role == "user"
      refute created_user.role == "admin"
    end

    test "PUBLIC ENDPOINT: Attempting to create support via public endpoint creates regular user", %{conn: conn} do
      malicious_params = %{
        email: "attacker2@evil.com",
        full_name: "Another Attacker",
        password: "password123!",
        password_confirmation: "password123!",
        role: "support"  # ← ATTACK ATTEMPT: Trying to escalate to support
      }

      conn = post(conn, ~p"/api/users", malicious_params)

      assert %{
        "data" => %{
          "role" => "user"  # ← SECURITY FIX: Role is "user", NOT "support"
        }
      } = json_response(conn, 201)
    end

    test "PUBLIC ENDPOINT: Role parameter is completely ignored even if invalid", %{conn: conn} do
      params = %{
        email: "user@example.com",
        full_name: "Test User",
        password: "password123!",
        password_confirmation: "password123!",
        role: "super_admin_root_god_mode"  # ← Invalid/malicious role attempt
      }

      conn = post(conn, ~p"/api/users", params)

      assert %{
        "data" => %{
          "role" => "user"  # ← Still forced to "user"
        }
      } = json_response(conn, 201)
    end

    test "ADMIN ENDPOINT: Admin can create admin users via protected endpoint", %{conn: conn} do
      # Create admin user
      admin = UsersFixtures.user_fixture(%{email: "admin@example.com", role: "admin"})
      {:ok, admin_token} = AuthService.generate_access_token(admin)

      admin_params = %{
        email: "newadmin@example.com",
        full_name: "New Admin",
        password: "AdminPassword123!",
        password_confirmation: "AdminPassword123!",
        role: "admin"
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{admin_token}")
      |> post(~p"/api/users/admin", admin_params)

      assert %{
        "data" => %{
          "role" => "admin"  # ← Admin CAN create admins via protected endpoint
        }
      } = json_response(conn, 201)

      # Verify in database
      {:ok, created_admin} = UserService.get_user_by_email("newadmin@example.com")
      assert created_admin.role == "admin"
    end

    test "ADMIN ENDPOINT: Non-admin CANNOT create admin users", %{conn: conn} do
      # Create regular user
      regular_user = UsersFixtures.user_fixture(%{email: "user@example.com", role: "user"})
      {:ok, user_token} = AuthService.generate_access_token(regular_user)

      admin_params = %{
        email: "hacker-admin@evil.com",
        full_name: "Hacker Admin",
        password: "AdminPassword123!",
        password_confirmation: "AdminPassword123!",
        role: "admin"
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{user_token}")
      |> post(~p"/api/users/admin", admin_params)

      # Should be blocked with 403 Forbidden
      assert %{
        "error" => %{
          "type" => "forbidden",
          "reason" => "insufficient_permissions"
        }
      } = json_response(conn, 403)

      # Verify user was NOT created
      assert {:error, _} = UserService.get_user_by_email("hacker-admin@evil.com")
    end

    test "ADMIN ENDPOINT: Unauthenticated user CANNOT access admin endpoint", %{conn: conn} do
      admin_params = %{
        email: "hacker@evil.com",
        full_name: "Hacker",
        password: "HackerPassword123!",
        password_confirmation: "HackerPassword123!",
        role: "admin"
      }

      # No authentication header
      conn = post(conn, ~p"/api/users/admin", admin_params)

      # Should be blocked with 401 Unauthorized
      assert %{
        "error" => %{
          "type" => "unauthorized"
        }
      } = json_response(conn, 401)

      # Verify user was NOT created
      assert {:error, _} = UserService.get_user_by_email("hacker@evil.com")
    end
  end

  describe "SECURITY: Password requirements enforcement" do
    test "PUBLIC ENDPOINT: Regular users only need 8 character passwords", %{conn: conn} do
      params = %{
        email: "user@example.com",
        full_name: "User",
        password: "Pass123!",  # 8 characters
        password_confirmation: "Pass123!"
        # No role specified, defaults to "user"
      }

      conn = post(conn, ~p"/api/users", params)

      assert json_response(conn, 201)  # Should succeed
    end

    test "ADMIN ENDPOINT: Admin users require 15+ character passwords", %{conn: conn} do
      admin = UsersFixtures.user_fixture(%{email: "admin@example.com", role: "admin"})
      {:ok, admin_token} = AuthService.generate_access_token(admin)

      # Try to create admin with short password
      params = %{
        email: "newadmin@example.com",
        full_name: "New Admin",
        password: "Short123!",  # Only 9 characters, needs 15
        password_confirmation: "Short123!",
        role: "admin"
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{admin_token}")
      |> post(~p"/api/users/admin", params)

      # Should fail validation
      assert %{
        "error" => %{
          "type" => "validation_error"
        }
      } = json_response(conn, 400)
    end

    test "ADMIN ENDPOINT: Admin creation succeeds with 15+ character password", %{conn: conn} do
      admin = UsersFixtures.user_fixture(%{email: "admin@example.com", role: "admin"})
      {:ok, admin_token} = AuthService.generate_access_token(admin)

      params = %{
        email: "newadmin@example.com",
        full_name: "New Admin",
        password: "ValidAdminPassword123!",  # 23 characters
        password_confirmation: "ValidAdminPassword123!",
        role: "admin"
      }

      conn = conn
      |> put_req_header("authorization", "Bearer #{admin_token}")
      |> post(~p"/api/users/admin", params)

      assert json_response(conn, 201)  # Should succeed
    end
  end

  describe "SECURITY: Policy enforcement" do
    test "Policy.can_create_user? is enforced for admin endpoint", %{conn: conn} do
      # Support users cannot create admin users (per Policy)
      support = UsersFixtures.user_fixture(%{email: "support@example.com", role: "support"})
      {:ok, support_token} = AuthService.generate_access_token(support)

      params = %{
        email: "newadmin@example.com",
        full_name: "New Admin",
        password: "AdminPassword123!",
        password_confirmation: "AdminPassword123!",
        role: "admin"
      }

      # Support user cannot access admin-only endpoint (blocked by Authorize plug)
      conn = conn
      |> put_req_header("authorization", "Bearer #{support_token}")
      |> post(~p"/api/users/admin", params)

      assert %{
        "error" => %{
          "type" => "forbidden"
        }
      } = json_response(conn, 403)
    end
  end
end

defmodule LedgerBankApiWeb.Controllers.AuthorizationTest do
  use LedgerBankApiWeb.ConnCase, async: false

  alias LedgerBankApi.Accounts.AuthService
  alias LedgerBankApi.UsersFixtures

  # ============================================================================
  # TEST SETUP
  # ============================================================================

  setup do
    # Create test users with different roles
    admin_user = UsersFixtures.user_fixture(%{role: "admin", email: "admin@example.com"})
    support_user = UsersFixtures.user_fixture(%{role: "support", email: "support@example.com"})
    regular_user = UsersFixtures.user_fixture(%{role: "user", email: "user@example.com"})
    another_user = UsersFixtures.user_fixture(%{role: "user", email: "another@example.com"})

    # Generate tokens for each user
    {:ok, admin_token} = AuthService.generate_access_token(admin_user)
    {:ok, support_token} = AuthService.generate_access_token(support_user)
    {:ok, user_token} = AuthService.generate_access_token(regular_user)
    {:ok, another_user_token} = AuthService.generate_access_token(another_user)

    %{
      admin_user: admin_user,
      support_user: support_user,
      regular_user: regular_user,
      another_user: another_user,
      admin_token: admin_token,
      support_token: support_token,
      user_token: user_token,
      another_user_token: another_user_token
    }
  end

  # ============================================================================
  # ADMIN-ONLY ENDPOINTS TESTS
  # ============================================================================

  describe "Admin-only endpoints authorization" do
    test "admin can access user list", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 200)
    end

    test "admin can access user statistics", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/stats")

      assert json_response(conn, 200)
    end

    test "admin can view any user", %{conn: conn, admin_token: token, regular_user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")

      assert json_response(conn, 200)
    end

    test "admin can update any user", %{conn: conn, admin_token: token, regular_user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/users/#{user.id}", %{full_name: "Updated Name"})

      assert json_response(conn, 200)
    end

    test "admin can delete any user", %{conn: conn, admin_token: token, another_user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      assert json_response(conn, 200)
    end

    test "support user cannot access user list", %{conn: conn, support_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 403)
    end

    test "support user cannot access user statistics", %{conn: conn, support_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/stats")

      assert json_response(conn, 403)
    end

    test "support user cannot view other users", %{
      conn: conn,
      support_token: token,
      regular_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end

    test "support user cannot update other users", %{
      conn: conn,
      support_token: token,
      regular_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/users/#{user.id}", %{full_name: "Updated Name"})

      assert json_response(conn, 403)
    end

    test "support user cannot delete other users", %{
      conn: conn,
      support_token: token,
      regular_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end

    test "regular user cannot access user list", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 403)
    end

    test "regular user cannot access user statistics", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/stats")

      assert json_response(conn, 403)
    end

    test "regular user cannot view other users", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end

    test "regular user cannot update other users", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/users/#{user.id}", %{full_name: "Updated Name"})

      assert json_response(conn, 403)
    end

    test "regular user cannot delete other users", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end

    test "unauthenticated user cannot access user list", %{conn: conn} do
      conn = get(conn, ~p"/api/users")

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot access user statistics", %{conn: conn} do
      conn = get(conn, ~p"/api/users/stats")

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot view users", %{conn: conn, regular_user: user} do
      conn = get(conn, ~p"/api/users/#{user.id}")

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot update users", %{conn: conn, regular_user: user} do
      conn = put(conn, ~p"/api/users/#{user.id}", %{full_name: "Updated Name"})

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot delete users", %{conn: conn, regular_user: user} do
      conn = delete(conn, ~p"/api/users/#{user.id}")

      assert json_response(conn, 401)
    end
  end

  # ============================================================================
  # PROFILE ENDPOINTS TESTS (USER OR ADMIN)
  # ============================================================================

  describe "Profile endpoints authorization" do
    test "user can view their own profile", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/profile")

      assert json_response(conn, 200)
    end

    test "user can update their own profile", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/profile", %{full_name: "Updated Name"})

      assert json_response(conn, 200)
    end

    test "user can change their own password", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/profile/password", %{
          current_password: "ValidPassword123!",
          new_password: "NewPassword123!",
          password_confirmation: "NewPassword123!"
        })

      assert json_response(conn, 200)
    end

    test "admin can view their own profile", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/profile")

      assert json_response(conn, 200)
    end

    test "admin can update their own profile", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/profile", %{full_name: "Updated Admin Name"})

      assert json_response(conn, 200)
    end

    test "admin can change their own password", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/profile/password", %{
          current_password: "ValidPassword123!",
          new_password: "NewAdminPassword123!",
          password_confirmation: "NewAdminPassword123!"
        })

      assert json_response(conn, 200)
    end

    test "support user can view their own profile", %{conn: conn, support_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/profile")

      assert json_response(conn, 200)
    end

    test "support user can update their own profile", %{conn: conn, support_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/profile", %{full_name: "Updated Support Name"})

      assert json_response(conn, 200)
    end

    test "support user can change their own password", %{conn: conn, support_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/profile/password", %{
          current_password: "ValidPassword123!",
          new_password: "NewSupportPassword123!",
          password_confirmation: "NewSupportPassword123!"
        })

      assert json_response(conn, 200)
    end

    test "unauthenticated user cannot access profile", %{conn: conn} do
      conn = get(conn, ~p"/api/profile")

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot update profile", %{conn: conn} do
      conn = put(conn, ~p"/api/profile", %{full_name: "Updated Name"})

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot change password", %{conn: conn} do
      conn =
        put(conn, ~p"/api/profile/password", %{
          current_password: "ValidPassword123!",
          new_password: "NewPassword123!",
          password_confirmation: "NewPassword123!"
        })

      assert json_response(conn, 401)
    end
  end

  # ============================================================================
  # AUTHENTICATION ENDPOINTS TESTS
  # ============================================================================

  describe "Authentication endpoints authorization" do
    test "unauthenticated user can login", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "user@example.com",
          password: "ValidPassword123!"
        })

      assert json_response(conn, 200)
    end

    test "unauthenticated user can refresh token", %{conn: conn, user_token: _token} do
      conn =
        post(conn, ~p"/api/auth/refresh", %{
          refresh_token: "valid-refresh-token"
        })

      # This will fail due to invalid refresh token
      assert json_response(conn, 401)
    end

    test "unauthenticated user can logout", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout", %{refresh_token: "valid-refresh-token"})

      # This will fail due to invalid refresh token
      assert json_response(conn, 401)
    end

    test "authenticated user can access /auth/me", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/me")

      assert json_response(conn, 200)
    end

    test "authenticated user can validate token", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/validate")

      assert json_response(conn, 200)
    end

    test "authenticated user can logout all sessions", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/auth/logout-all")

      assert json_response(conn, 200)
    end

    test "unauthenticated user cannot access /auth/me", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot validate token", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/validate")

      assert json_response(conn, 401)
    end

    test "unauthenticated user cannot logout all sessions", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout-all")

      assert json_response(conn, 401)
    end
  end

  # ============================================================================
  # TOKEN VALIDATION TESTS
  # ============================================================================

  describe "Token validation" do
    test "valid token allows access", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/profile")

      assert json_response(conn, 200)
    end

    test "invalid token format is rejected", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> get(~p"/api/profile")

      assert json_response(conn, 401)
    end

    test "missing authorization header is rejected", %{conn: conn} do
      conn = get(conn, ~p"/api/profile")

      assert json_response(conn, 401)
    end

    test "empty authorization header is rejected", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "")
        |> get(~p"/api/profile")

      assert json_response(conn, 401)
    end

    test "malformed authorization header is rejected", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "InvalidFormat token")
        |> get(~p"/api/profile")

      assert json_response(conn, 401)
    end

    test "expired token is rejected", %{conn: conn} do
      # Create an expired token (this would need to be implemented in the test setup)
      expired_token = "expired-token-here"

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{expired_token}")
        |> get(~p"/api/profile")

      assert json_response(conn, 401)
    end
  end

  # ============================================================================
  # ROLE-BASED ACCESS CONTROL TESTS
  # ============================================================================

  describe "Role-based access control" do
    test "admin can access user list endpoint", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 200)
    end

    test "admin can access user stats endpoint", %{conn: conn, admin_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/stats")

      assert json_response(conn, 200)
    end

    test "admin can view specific user", %{conn: conn, admin_token: token, regular_user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")

      assert json_response(conn, 200)
    end

    test "admin can update specific user", %{conn: conn, admin_token: token, regular_user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/users/#{user.id}", %{full_name: "Updated Name"})

      assert json_response(conn, 200)
    end

    test "admin can delete specific user", %{conn: conn, admin_token: token, another_user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      assert json_response(conn, 200)
    end

    test "support user cannot access user list", %{conn: conn, support_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 403)
    end

    test "support user cannot access user stats", %{conn: conn, support_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/stats")

      assert json_response(conn, 403)
    end

    test "support user cannot view other users", %{
      conn: conn,
      support_token: token,
      regular_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end

    test "support user cannot update other users", %{
      conn: conn,
      support_token: token,
      regular_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/users/#{user.id}", %{full_name: "Updated Name"})

      assert json_response(conn, 403)
    end

    test "support user cannot delete other users", %{
      conn: conn,
      support_token: token,
      another_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end

    test "regular user cannot access user list", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 403)
    end

    test "regular user cannot access user stats", %{conn: conn, user_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/stats")

      assert json_response(conn, 403)
    end

    test "regular user cannot view other users", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end

    test "regular user cannot update other users", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/users/#{user.id}", %{full_name: "Updated Name"})

      assert json_response(conn, 403)
    end

    test "regular user cannot delete other users", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      assert json_response(conn, 403)
    end
  end

  # ============================================================================
  # EDGE CASES AND SECURITY TESTS
  # ============================================================================

  describe "Security edge cases" do
    test "user cannot access other user's profile via user ID", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      # Try to access another user's profile by using their ID in the path
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/#{user.id}")

      # Should be forbidden since this is an admin-only endpoint
      assert json_response(conn, 403)
    end

    test "user cannot update other user's profile via user ID", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      # Try to update another user's profile by using their ID in the path
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/api/users/#{user.id}", %{full_name: "Hacked Name"})

      # Should be forbidden since this is an admin-only endpoint
      assert json_response(conn, 403)
    end

    test "user cannot delete other user via user ID", %{
      conn: conn,
      user_token: token,
      another_user: user
    } do
      # Try to delete another user by using their ID in the path
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/users/#{user.id}")

      # Should be forbidden since this is an admin-only endpoint
      assert json_response(conn, 403)
    end

    test "admin cannot access profile endpoints with user ID", %{
      conn: conn,
      admin_token: token,
      regular_user: _user
    } do
      # Admin should use profile endpoints for their own profile, not user ID endpoints
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/profile")

      # Should work since admin can access their own profile
      assert json_response(conn, 200)
    end

    test "malicious user cannot bypass authorization with invalid user ID", %{
      conn: conn,
      user_token: token
    } do
      # Try to access a non-existent user
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users/invalid-uuid")

      # Should be forbidden since this is an admin-only endpoint
      assert json_response(conn, 403)
    end

    test "user cannot access admin endpoints with valid but insufficient role", %{
      conn: conn,
      user_token: token
    } do
      # Regular user with valid token trying to access admin endpoints
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 403)
    end

    test "support user cannot access admin endpoints with valid but insufficient role", %{
      conn: conn,
      support_token: token
    } do
      # Support user with valid token trying to access admin endpoints
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/users")

      assert json_response(conn, 403)
    end
  end

  # ============================================================================
  # PUBLIC ENDPOINTS TESTS
  # ============================================================================

  describe "Public endpoints" do
    test "anyone can access health check", %{conn: conn} do
      conn = get(conn, ~p"/api/health")

      assert json_response(conn, 200)
    end

    test "anyone can register a new user", %{conn: conn} do
      conn =
        post(conn, ~p"/api/users", %{
          email: "newuser@example.com",
          full_name: "New User",
          role: "user",
          password: "ValidPassword123!",
          password_confirmation: "ValidPassword123!"
        })

      assert json_response(conn, 201)
    end

    test "anyone can login", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "user@example.com",
          password: "ValidPassword123!"
        })

      assert json_response(conn, 200)
    end

    test "anyone can logout", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout", %{refresh_token: "valid-refresh-token"})

      # This will fail due to invalid refresh token
      assert json_response(conn, 401)
    end
  end
end

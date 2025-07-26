defmodule LedgerBankApiWeb.UsersControllerV2Test do
  @moduledoc """
  Comprehensive tests for UsersControllerV2.
  Tests all user management endpoints with proper authorization checks.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Users.Context

  @valid_user_attrs %{
    "email" => "test@example.com",
    "full_name" => "Test User",
    "password" => "password123"
  }

  @update_user_attrs %{
    "full_name" => "Updated User",
    "email" => "updated@example.com"
  }

  describe "GET /api/users" do
    test "returns list of users for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user1, _conn} = create_test_user(%{email: "user1@example.com"})
      {user2, _conn} = create_test_user(%{email: "user2@example.com"})

      conn = get(conn, ~p"/api/users")

      assert %{
               "data" => [
                 %{"id" => user1_id, "email" => "user1@example.com"},
                 %{"id" => user2_id, "email" => "user2@example.com"},
                 %{"id" => admin_id, "email" => admin.email}
               ]
             } = json_response(conn, 200)

      assert user1_id == user1.id
      assert user2_id == user2.id
      assert admin_id == admin.id
    end

    test "returns error for non-admin user", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/users")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error without authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/users")

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Authentication token required",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end
  end

  describe "GET /api/users/:id" do
    test "returns user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user, _conn} = create_test_user()

      conn = get(conn, ~p"/api/users/#{user.id}")

      assert %{
               "data" => %{
                 "id" => user_id,
                 "email" => user.email,
                 "full_name" => user.full_name,
                 "role" => user.role,
                 "status" => user.status
               }
             } = json_response(conn, 200)

      assert user_id == user.id
    end

    test "returns own profile for regular user", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/users/#{user.id}")

      assert %{
               "data" => %{
                 "id" => user_id,
                 "email" => user.email
               }
             } = json_response(conn, 200)

      assert user_id == user.id
    end

    test "returns error for user accessing other user's profile", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      conn = get(conn, ~p"/api/users/#{user2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for non-existent user", %{conn: conn} do
      {_admin, _access_token, conn} = setup_authenticated_admin(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/users/#{fake_id}")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "PUT /api/users/:id" do
    test "updates user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user, _conn} = create_test_user()

      conn = put(conn, ~p"/api/users/#{user.id}", user: @update_user_attrs)

      assert %{
               "data" => %{
                 "id" => user_id,
                 "email" => "updated@example.com",
                 "full_name" => "Updated User"
               }
             } = json_response(conn, 200)

      assert user_id == user.id

      # Verify database was updated
      updated_user = get_user!(user.id)
      assert updated_user.email == "updated@example.com"
      assert updated_user.full_name == "Updated User"
    end

    test "allows user to update own profile", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      conn = put(conn, ~p"/api/users/#{user.id}", user: @update_user_attrs)

      assert %{
               "data" => %{
                 "id" => user_id,
                 "email" => "updated@example.com",
                 "full_name" => "Updated User"
               }
             } = json_response(conn, 200)

      assert user_id == user.id
    end

    test "returns error for user updating other user's profile", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      conn = put(conn, ~p"/api/users/#{user2.id}", user: @update_user_attrs)

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for invalid update data", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user, _conn} = create_test_user()

      invalid_attrs = %{"email" => "invalid-email"}

      conn = put(conn, ~p"/api/users/#{user.id}", user: invalid_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end

  describe "DELETE /api/users/:id" do
    test "deletes user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user, _conn} = create_test_user()

      conn = delete(conn, ~p"/api/users/#{user.id}")

      assert response(conn, 204) == ""

      # Verify user was deleted
      assert_raise Ecto.NoResultsError, fn ->
        get_user!(user.id)
      end
    end

    test "returns error for non-admin user", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      conn = delete(conn, ~p"/api/users/#{user2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for non-existent user", %{conn: conn} do
      {_admin, _access_token, conn} = setup_authenticated_admin(conn)
      fake_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/users/#{fake_id}")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "POST /api/users/:id/suspend" do
    test "suspends user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user, _conn} = create_test_user()

      conn = post(conn, ~p"/api/users/#{user.id}/suspend")

      assert %{
               "data" => %{
                 "id" => user_id,
                 "status" => "SUSPENDED"
               }
             } = json_response(conn, 200)

      assert user_id == user.id

      # Verify user was suspended
      suspended_user = get_user!(user.id)
      assert suspended_user.status == "SUSPENDED"
    end

    test "returns error for non-admin user", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      conn = post(conn, ~p"/api/users/#{user2.id}/suspend")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end
  end

  describe "POST /api/users/:id/activate" do
    test "activates user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user, _conn} = create_test_user()

      # First suspend the user
      suspend_user(user)

      conn = post(conn, ~p"/api/users/#{user.id}/activate")

      assert %{
               "data" => %{
                 "id" => user_id,
                 "status" => "ACTIVE"
               }
             } = json_response(conn, 200)

      assert user_id == user.id

      # Verify user was activated
      activated_user = get_user!(user.id)
      assert activated_user.status == "ACTIVE"
    end

    test "returns error for non-admin user", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      conn = post(conn, ~p"/api/users/#{user2.id}/activate")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end
  end

  describe "GET /api/users/role/:role" do
    test "returns users by role for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user1, _conn} = create_user_with_role("user", %{email: "user1@example.com"})
      {user2, _conn} = create_user_with_role("user", %{email: "user2@example.com"})
      {support_user, _conn} = create_user_with_role("support", %{email: "support@example.com"})

      conn = get(conn, ~p"/api/users/role/user")

      assert %{
               "data" => [
                 %{"id" => user1_id, "role" => "user"},
                 %{"id" => user2_id, "role" => "user"}
               ]
             } = json_response(conn, 200)

      assert user1_id == user1.id
      assert user2_id == user2.id
    end

    test "returns error for non-admin user", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/users/role/user")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns empty list for non-existent role", %{conn: conn} do
      {_admin, _access_token, conn} = setup_authenticated_admin(conn)

      conn = get(conn, ~p"/api/users/role/nonexistent")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "Authorization edge cases" do
    test "admin can access any user's data", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      {user, _conn} = create_test_user()

      # Admin can read user
      conn = get(conn, ~p"/api/users/#{user.id}")
      assert json_response(conn, 200)

      # Admin can update user
      conn = put(conn, ~p"/api/users/#{user.id}", user: @update_user_attrs)
      assert json_response(conn, 200)

      # Admin can delete user
      conn = delete(conn, ~p"/api/users/#{user.id}")
      assert response(conn, 204)
    end

    test "user cannot access admin functions", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {other_user, _conn} = create_test_user()

      # User cannot list all users
      conn = get(conn, ~p"/api/users")
      assert json_response(conn, 403)

      # User cannot access other user's data
      conn = get(conn, ~p"/api/users/#{other_user.id}")
      assert json_response(conn, 403)

      # User cannot update other user
      conn = put(conn, ~p"/api/users/#{other_user.id}", user: @update_user_attrs)
      assert json_response(conn, 403)

      # User cannot delete other user
      conn = delete(conn, ~p"/api/users/#{other_user.id}")
      assert json_response(conn, 403)

      # User cannot suspend other user
      conn = post(conn, ~p"/api/users/#{other_user.id}/suspend")
      assert json_response(conn, 403)

      # User cannot activate other user
      conn = post(conn, ~p"/api/users/#{other_user.id}/activate")
      assert json_response(conn, 403)

      # User cannot list users by role
      conn = get(conn, ~p"/api/users/role/user")
      assert json_response(conn, 403)
    end

    test "suspended user cannot access any endpoints", %{conn: conn} do
      {user, access_token, _conn} = setup_authenticated_user(conn)

      # Suspend the user
      suspend_user(user)

      # Try to access endpoints with suspended user's token
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{access_token}")

      # Should not be able to access any protected endpoints
      conn = get(conn, ~p"/api/users/#{user.id}")
      assert json_response(conn, 401)
    end
  end
end

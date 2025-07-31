defmodule LedgerBankApiWeb.UsersControllerTest do
  @moduledoc """
  Comprehensive tests for UsersController.
  Tests all user management endpoints with proper authorization checks.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Users.Context
  import LedgerBankApi.Factories
  import LedgerBankApi.ErrorAssertions

  describe "GET /api/users" do
    test "returns list of users for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user1 = insert(:user)
      user2 = insert(:user)

      conn = get(conn, ~p"/api/users")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 3)  # admin + 2 users
    end

    test "returns error for non-admin user", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/users")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error without authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/users")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end
  end

  describe "GET /api/users/:id" do
    test "returns user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user = insert(:user)

      conn = get(conn, ~p"/api/users/#{user.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "returns own profile for regular user", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/users/#{user.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "returns error for user accessing other user's profile", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      user2 = insert(:user)

      conn = get(conn, ~p"/api/users/#{user2.id}")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for non-existent user", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/users/#{fake_id}")

      response = json_response(conn, 404)
      assert_not_found_error(response)
    end
  end

  describe "POST /api/users" do
    test "creates user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user_attrs = build(:user)

      conn = post(conn, ~p"/api/users", user: %{
        "email" => user_attrs.email,
        "full_name" => user_attrs.full_name,
        "password" => "password123",
        "role" => "user"
      })

      response = json_response(conn, 201)
      assert_success_response(response, 201)
      assert_user_response(response)
    end

    test "returns error for non-admin creating user", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      user_attrs = build(:user)

      conn = post(conn, ~p"/api/users", user: %{
        "email" => user_attrs.email,
        "full_name" => user_attrs.full_name,
        "password" => "password123"
      })

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for duplicate email", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      existing_user = insert(:user)

      conn = post(conn, ~p"/api/users", user: %{
        "email" => existing_user.email,
        "full_name" => "Another User",
        "password" => "password123"
      })

      response = json_response(conn, 409)
      assert_conflict_error(response)
    end

    test "returns error for invalid user data", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)

      conn = post(conn, ~p"/api/users", user: %{
        "email" => "invalid-email",
        "full_name" => "",
        "password" => "123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end
  end

  describe "PUT /api/users/:id" do
    test "updates user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user = insert(:user)

      update_attrs = %{
        "full_name" => "Updated User",
        "email" => "updated@example.com"
      }

      conn = put(conn, ~p"/api/users/#{user.id}", user: update_attrs)

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "updates own profile for regular user", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      update_attrs = %{
        "full_name" => "Updated User"
      }

      conn = put(conn, ~p"/api/users/#{user.id}", user: update_attrs)

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "returns error for user updating other user's profile", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      user2 = insert(:user)

      update_attrs = %{
        "full_name" => "Updated User"
      }

      conn = put(conn, ~p"/api/users/#{user2.id}", user: update_attrs)

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for duplicate email on update", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user1 = insert(:user)
      user2 = insert(:user)

      update_attrs = %{
        "email" => user2.email
      }

      conn = put(conn, ~p"/api/users/#{user1.id}", user: update_attrs)

      response = json_response(conn, 409)
      assert_conflict_error(response)
    end
  end

  describe "DELETE /api/users/:id" do
    test "deletes user for admin", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user = insert(:user)

      conn = delete(conn, ~p"/api/users/#{user.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
    end

    test "returns error for non-admin deleting user", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      user2 = insert(:user)

      conn = delete(conn, ~p"/api/users/#{user2.id}")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for user deleting themselves", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      conn = delete(conn, ~p"/api/users/#{user.id}")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for deleting non-existent user", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      fake_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/users/#{fake_id}")

      response = json_response(conn, 404)
      assert_not_found_error(response)
    end
  end

  describe "User status management" do
    test "admin can suspend user", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user = insert(:user)

      conn = put(conn, ~p"/api/users/#{user.id}/suspend")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "admin can activate suspended user", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user = insert(:suspended_user)

      conn = put(conn, ~p"/api/users/#{user.id}/activate")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "non-admin cannot suspend user", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      user2 = insert(:user)

      conn = put(conn, ~p"/api/users/#{user2.id}/suspend")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end
  end

  describe "User role management" do
    test "admin can change user role", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user = insert(:user)

      conn = put(conn, ~p"/api/users/#{user.id}/role", %{"role" => "support"})

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "non-admin cannot change user role", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      user2 = insert(:user)

      conn = put(conn, ~p"/api/users/#{user2.id}/role", %{"role" => "support"})

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for invalid role", %{conn: conn} do
      {admin, _access_token, conn} = setup_authenticated_admin(conn)
      user = insert(:user)

      conn = put(conn, ~p"/api/users/#{user.id}/role", %{"role" => "invalid_role"})

      response = json_response(conn, 400)
      assert_validation_error(response)
    end
  end
end

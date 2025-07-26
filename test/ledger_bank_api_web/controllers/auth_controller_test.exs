defmodule LedgerBankApiWeb.AuthControllerV2Test do
  @moduledoc """
  Comprehensive tests for AuthControllerV2.
  Tests all authentication endpoints: register, login, refresh, logout, and me.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Users.Context
  alias LedgerBankApi.Users.User

  @valid_user_attrs %{
    "email" => "test@example.com",
    "full_name" => "Test User",
    "password" => "password123"
  }

  @valid_login_attrs %{
    "email" => "test@example.com",
    "password" => "password123"
  }

  describe "POST /api/auth/register" do
    test "creates a new user and returns tokens", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", user: @valid_user_attrs)

      assert %{
               "data" => %{
                 "user" => %{
                   "id" => user_id,
                   "email" => "test@example.com",
                   "full_name" => "Test User",
                   "role" => "user",
                   "status" => "ACTIVE"
                 },
                 "access_token" => access_token,
                 "refresh_token" => refresh_token
               },
               "message" => "User registered successfully"
             } = json_response(conn, 201)

      assert is_binary(user_id)
      assert is_binary(access_token)
      assert is_binary(refresh_token)

      # Verify user was created in database
      user = get_user!(user_id)
      assert user.email == "test@example.com"
      assert user.full_name == "Test User"
      assert user.role == "user"
      assert user.status == "ACTIVE"
    end

    test "returns error for invalid email format", %{conn: conn} do
      invalid_attrs = Map.put(@valid_user_attrs, "email", "invalid-email")
      conn = post(conn, ~p"/api/auth/register", user: invalid_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "returns error for duplicate email", %{conn: conn} do
      # Create first user
      post(conn, ~p"/api/auth/register", user: @valid_user_attrs)

      # Try to create second user with same email
      conn = post(conn, ~p"/api/auth/register", user: @valid_user_attrs)

      assert %{
               "error" => %{
                 "type" => "conflict",
                 "message" => "Constraint violation: users_email_index",
                 "code" => 409
               }
             } = json_response(conn, 409)
    end

    test "returns error for weak password", %{conn: conn} do
      weak_password_attrs = Map.put(@valid_user_attrs, "password", "123")
      conn = post(conn, ~p"/api/auth/register", user: weak_password_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "returns error for missing required fields", %{conn: conn} do
      incomplete_attrs = %{"email" => "test@example.com"}
      conn = post(conn, ~p"/api/auth/register", user: incomplete_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/auth/login" do
    setup do
      # Create a user for login tests
      {:ok, user} = create_user(@valid_user_attrs)
      %{user: user}
    end

    test "logs in user with valid credentials and returns tokens", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/auth/login", @valid_login_attrs)

      assert %{
               "data" => %{
                 "user" => %{
                   "id" => user_id,
                   "email" => "test@example.com",
                   "full_name" => "Test User"
                 },
                 "access_token" => access_token,
                 "refresh_token" => refresh_token
               },
               "message" => "Login successful"
             } = json_response(conn, 200)

      assert user_id == user.id
      assert is_binary(access_token)
      assert is_binary(refresh_token)
    end

    test "returns error for invalid email", %{conn: conn} do
      invalid_attrs = Map.put(@valid_login_attrs, "email", "nonexistent@example.com")
      conn = post(conn, ~p"/api/auth/login", invalid_attrs)

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Unauthorized access",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end

    test "returns error for invalid password", %{conn: conn} do
      invalid_attrs = Map.put(@valid_login_attrs, "password", "wrongpassword")
      conn = post(conn, ~p"/api/auth/login", invalid_attrs)

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Unauthorized access",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end

    test "returns error for suspended user", %{conn: conn, user: user} do
      # Suspend the user
      suspend_user(user)

      conn = post(conn, ~p"/api/auth/login", @valid_login_attrs)

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Unauthorized access",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end
  end

  describe "POST /api/auth/refresh" do
    setup do
      # Create a user and get refresh token
      {:ok, user} = create_user(@valid_user_attrs)
      {:ok, _access_token, refresh_token} = login_user(user.email, @valid_user_attrs["password"])
      %{user: user, refresh_token: refresh_token}
    end

    test "refreshes tokens with valid refresh token", %{conn: conn, user: user, refresh_token: refresh_token} do
      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => refresh_token})

      assert %{
               "data" => %{
                 "user" => %{
                   "id" => user_id,
                   "email" => "test@example.com"
                 },
                 "access_token" => new_access_token,
                 "refresh_token" => new_refresh_token
               },
               "message" => "Tokens refreshed successfully"
             } = json_response(conn, 200)

      assert user_id == user.id
      assert is_binary(new_access_token)
      assert is_binary(new_refresh_token)
      assert new_access_token != refresh_token
      assert new_refresh_token != refresh_token
    end

    test "returns error for invalid refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => "invalid_token"})

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Unauthorized access",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end

    test "returns error for expired refresh token", %{conn: conn, user: user} do
      # Create an expired refresh token (this would require mocking time)
      # For now, we'll test with a malformed token
      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => "expired_token"})

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Unauthorized access",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end

    test "returns error for missing refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{})

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end

  describe "POST /api/logout" do
    setup do
      # Create a user and get access token
      {:ok, user} = create_user(@valid_user_attrs)
      {:ok, access_token, _refresh_token} = login_user(user.email, @valid_user_attrs["password"])
      %{user: user, access_token: access_token}
    end

    test "logs out user and revokes all refresh tokens", %{conn: conn, access_token: access_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> post(~p"/api/logout")

      assert %{
               "message" => "Logout successful",
               "data" => %{}
             } = json_response(conn, 200)
    end

    test "returns error without authentication", %{conn: conn} do
      conn = post(conn, ~p"/api/logout")

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Authentication token required",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end

    test "returns error with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> post(~p"/api/logout")

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Invalid authentication token: invalid_token",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end
  end

  describe "GET /api/me" do
    setup do
      # Create a user and get access token
      {:ok, user} = create_user(@valid_user_attrs)
      {:ok, access_token, _refresh_token} = login_user(user.email, @valid_user_attrs["password"])
      %{user: user, access_token: access_token}
    end

    test "returns current user profile", %{conn: conn, user: user, access_token: access_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/me")

      assert %{
               "data" => %{
                 "id" => user_id,
                 "email" => "test@example.com",
                 "full_name" => "Test User",
                 "role" => "user",
                 "status" => "ACTIVE"
               }
             } = json_response(conn, 200)

      assert user_id == user.id
    end

    test "returns error without authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/me")

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Authentication token required",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end

    test "returns error with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> get(~p"/api/me")

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Invalid authentication token: invalid_token",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end

    test "returns error for suspended user", %{conn: conn, user: user, access_token: access_token} do
      # Suspend the user
      suspend_user(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/me")

      assert %{
               "error" => %{
                 "type" => "unauthorized",
                 "message" => "Invalid authentication token: User not found",
                 "code" => 401
               }
             } = json_response(conn, 401)
    end
  end

  describe "Admin user registration" do
    test "creates admin user when role is specified", %{conn: conn} do
      admin_attrs = Map.put(@valid_user_attrs, "role", "admin")
      conn = post(conn, ~p"/api/auth/register", user: admin_attrs)

      assert %{
               "data" => %{
                 "user" => %{
                   "role" => "admin"
                 }
               }
             } = json_response(conn, 201)

      # Verify user was created with admin role
      user = get_user_by_email("test@example.com")
      assert user.role == "admin"
    end

    test "defaults to user role when not specified", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", user: @valid_user_attrs)

      assert %{
               "data" => %{
                 "user" => %{
                   "role" => "user"
                 }
               }
             } = json_response(conn, 201)

      # Verify user was created with user role
      user = get_user_by_email("test@example.com")
      assert user.role == "user"
    end
  end

  describe "JWT token validation" do
    setup do
      # Create a user and get tokens
      {:ok, user} = create_user(@valid_user_attrs)
      {:ok, access_token, refresh_token} = login_user(user.email, @valid_user_attrs["password"])
      %{user: user, access_token: access_token, refresh_token: refresh_token}
    end

    test "access token contains correct claims", %{access_token: access_token} do
      {:ok, claims} = LedgerBankApi.Auth.JWT.verify_token(access_token)

      assert claims["type"] == "access"
      assert claims["role"] == "user"
      assert is_binary(claims["sub"])
      assert is_integer(claims["exp"])
    end

    test "refresh token contains correct claims", %{refresh_token: refresh_token} do
      {:ok, claims} = LedgerBankApi.Auth.JWT.verify_token(refresh_token)

      assert claims["type"] == "refresh"
      assert claims["role"] == "user"
      assert is_binary(claims["sub"])
      assert is_binary(claims["jti"])
      assert is_integer(claims["exp"])
    end

    test "tokens are different", %{access_token: access_token, refresh_token: refresh_token} do
      assert access_token != refresh_token
    end
  end
end

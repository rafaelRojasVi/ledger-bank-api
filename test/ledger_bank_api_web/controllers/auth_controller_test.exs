defmodule LedgerBankApiWeb.AuthControllerTest do
  @moduledoc """
  Comprehensive tests for AuthController.
  Tests all authentication endpoints: register, login, refresh, logout, and me.
  Includes performance testing, edge cases, and comprehensive error handling.
  """

  use LedgerBankApiWeb.ConnCase, async: false
  import LedgerBankApi.Users.Context, only: [suspend_user: 1, login_user: 2]
  import LedgerBankApi.Factories
  import LedgerBankApi.ErrorAssertions
  import Ecto.Query

  @valid_user_attrs %{
    "email" => "test@example.com",
    "full_name" => "Test User",
    "password" => "password123"
  }

  @concurrent_users 20
  @performance_threshold_ms 2000

  describe "POST /api/auth/register" do
    test "creates a new user and returns tokens", %{conn: conn} do
      user_attrs = build(:user)

      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => user_attrs.email,
        "full_name" => user_attrs.full_name,
        "password" => "password123"
      })

      response = json_response(conn, 201)

      assert_success_response(response, 201)
      assert_auth_tokens_response(response)
      assert_user_response(response)

      # Verify user was created in database
      assert %{"data" => %{"user" => %{"id" => user_id}}} = response
      user = LedgerBankApi.Users.Context.get!(user_id)
      assert user.email == user_attrs.email
      assert user.full_name == user_attrs.full_name
      assert user.role == "user"
      assert user.status == "ACTIVE"
    end

    test "returns error for invalid email format", %{conn: conn} do
      user_attrs = build(:user)
      invalid_attrs = Map.put(user_attrs, :email, "invalid-email")

      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => invalid_attrs.email,
        "full_name" => invalid_attrs.full_name,
        "password" => "password123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for duplicate email", %{conn: conn} do
      user_attrs = build(:user)

      # Create first user
      post(conn, ~p"/api/auth/register", user: %{
        "email" => user_attrs.email,
        "full_name" => user_attrs.full_name,
        "password" => "password123"
      })

      # Try to create second user with same email
      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => user_attrs.email,
        "full_name" => user_attrs.full_name,
        "password" => "password123"
      })

      response = json_response(conn, 409)
      assert_conflict_error(response)
    end

    test "returns error for weak password", %{conn: conn} do
      user_attrs = build(:user)

      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => user_attrs.email,
        "full_name" => user_attrs.full_name,
        "password" => "123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for missing required fields", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => "test@example.com"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for empty email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => "",
        "full_name" => "Test User",
        "password" => "password123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for empty full_name", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => "test@example.com",
        "full_name" => "",
        "password" => "password123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for extremely long email", %{conn: conn} do
      long_email = String.duplicate("a", 300) <> "@example.com"

      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => long_email,
        "full_name" => "Test User",
        "password" => "password123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for extremely long full_name", %{conn: conn} do
      long_name = String.duplicate("a", 300)

      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => "test@example.com",
        "full_name" => long_name,
        "password" => "password123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for extremely long password", %{conn: conn} do
      long_password = String.duplicate("a", 1000)

      conn = post(conn, ~p"/api/auth/register", user: %{
        "email" => "test@example.com",
        "full_name" => "Test User",
        "password" => long_password
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "handles concurrent registrations efficiently", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      results =
        1..@concurrent_users
        |> Task.async_stream(fn i ->
          user_data = %{
            "user" => %{
              "email" => "concurrent#{i}@example.com",
              "full_name" => "Concurrent User #{i}",
              "password" => "password123"
            }
          }

          conn
          |> post(~p"/api/auth/register", user_data)
          |> json_response(201)
        end, max_concurrency: 5, timeout: 30_000)
        |> Enum.to_list()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # All registrations should succeed
      assert Enum.all?(results, fn {:ok, response} ->
        assert_success_response(response, 201)
        assert_auth_tokens_response(response)
      end)

      # Performance assertion
      assert duration < @performance_threshold_ms
    end
  end

  describe "POST /api/auth/login" do
    test "logs in user with valid credentials and returns tokens", %{conn: conn} do
      user = insert(:user)

      conn = post(conn, ~p"/api/auth/login", %{
        "email" => user.email,
        "password" => "password123"
      })

      response = json_response(conn, 200)

      assert_success_response(response, 200)
      assert_auth_tokens_response(response)
      assert_user_response(response)
    end

    test "returns error for invalid email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{
        "email" => "nonexistent@example.com",
        "password" => "password123"
      })

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for invalid password", %{conn: conn} do
      user = insert(:user)

      conn = post(conn, ~p"/api/auth/login", %{
        "email" => user.email,
        "password" => "wrongpassword"
      })

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for suspended user", %{conn: conn} do
      user = insert(:suspended_user)

      conn = post(conn, ~p"/api/auth/login", %{
        "email" => user.email,
        "password" => "password123"
      })

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for empty email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{
        "email" => "",
        "password" => "password123"
      })

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for empty password", %{conn: conn} do
      user = insert(:user)

      conn = post(conn, ~p"/api/auth/login", %{
        "email" => user.email,
        "password" => ""
      })

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for missing email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{
        "password" => "password123"
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for missing password", %{conn: conn} do
      user = insert(:user)

      conn = post(conn, ~p"/api/auth/login", %{
        "email" => user.email
      })

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "handles concurrent logins efficiently", %{conn: conn} do
      # Create test users
      users = for i <- 1..@concurrent_users do
        insert(:user, email: "login#{i}@example.com", full_name: "Login User #{i}")
      end

      start_time = System.monotonic_time(:millisecond)

      results =
        users
        |> Task.async_stream(fn user ->
          login_data = %{
            "email" => user.email,
            "password" => "password123"
          }

          conn
          |> post(~p"/api/auth/login", login_data)
          |> json_response(200)
        end, max_concurrency: 5, timeout: 30_000)
        |> Enum.to_list()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # All logins should succeed
      assert Enum.all?(results, fn {:ok, response} ->
        assert_success_response(response, 200)
        assert_auth_tokens_response(response)
      end)

      # Performance assertion
      assert duration < @performance_threshold_ms
    end
  end

  describe "POST /api/auth/refresh" do
    test "refreshes tokens with valid refresh token", %{conn: conn} do
      {_user, _access_token, refresh_token} = create_user_with_tokens()

      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => refresh_token})

      response = json_response(conn, 200)

      assert_success_response(response, 200)
      assert_auth_tokens_response(response)
      assert_user_response(response)
    end

    test "returns error for invalid refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => "invalid_token"})

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for expired refresh token", %{conn: conn} do
      {_user, _access_token, refresh_token} = create_user_with_tokens()

      # Manually expire the token by updating the database
      with {:ok, claims} <- LedgerBankApi.Auth.JWT.verify_token(refresh_token),
           jti when is_binary(jti) <- claims["jti"],
           token <- LedgerBankApi.Users.Context.get_refresh_token_by_jti(jti) do
        if token do
          token
          |> LedgerBankApi.Users.RefreshToken.changeset(%{expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)})
          |> LedgerBankApi.Repo.update()
        end
      end

      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => refresh_token})

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for missing refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{})

      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "returns error for empty refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => ""})

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for revoked refresh token", %{conn: conn} do
      {_user, _access_token, refresh_token} = create_user_with_tokens()

      # Manually revoke the token
      with {:ok, claims} <- LedgerBankApi.Auth.JWT.verify_token(refresh_token),
           jti when is_binary(jti) <- claims["jti"],
           token <- LedgerBankApi.Users.Context.get_refresh_token_by_jti(jti) do
        if token do
          token
          |> LedgerBankApi.Users.RefreshToken.changeset(%{revoked_at: DateTime.utc_now()})
          |> LedgerBankApi.Repo.update()
        end
      end

      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => refresh_token})

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "handles concurrent token refreshes efficiently", %{conn: conn} do
      # Create users and get refresh tokens
      refresh_tokens =
        1..@concurrent_users
        |> Task.async_stream(fn i ->
          user = insert(:user, email: "refresh#{i}@example.com")
          {:ok, _user, _access_token, refresh_token} = login_user(user.email, "password123")
          refresh_token
        end, max_concurrency: 5, timeout: 10_000)
        |> Enum.map(fn {:ok, token} -> token end)

      start_time = System.monotonic_time(:millisecond)

      results =
        refresh_tokens
        |> Task.async_stream(fn refresh_token ->
          conn
          |> post(~p"/api/auth/refresh", %{"refresh_token" => refresh_token})
          |> json_response(200)
        end, max_concurrency: 5, timeout: 30_000)
        |> Enum.to_list()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # All refreshes should succeed
      assert Enum.all?(results, fn {:ok, response} ->
        assert_success_response(response, 200)
        assert_auth_tokens_response(response)
      end)

      # Performance assertion
      assert duration < @performance_threshold_ms
    end
  end

  describe "POST /api/logout" do
    test "logs out user and revokes all refresh tokens", %{conn: conn} do
      {user, access_token, _refresh_token} = create_user_with_tokens()

      conn = conn
             |> put_req_header("authorization", "Bearer #{access_token}")
             |> post(~p"/api/logout")

      response = json_response(conn, 200)
      assert_success_with_message(response, "Logged out successfully")

      # Verify all refresh tokens are revoked
      tokens = LedgerBankApi.Repo.all(from t in LedgerBankApi.Users.RefreshToken, where: t.user_id == ^user.id)
      assert Enum.all?(tokens, &LedgerBankApi.Users.RefreshToken.revoked?/1)
    end

    test "returns error without authentication", %{conn: conn} do
      conn = post(conn, ~p"/api/logout")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error with invalid token", %{conn: conn} do
      conn = conn
             |> put_req_header("authorization", "Bearer invalid_token")
             |> post(~p"/api/logout")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error with expired token", %{conn: conn} do
      {_user, _access_token, _refresh_token} = create_user_with_tokens()

      # Manually expire the access token by creating a new one with past expiration
      user = insert(:user, email: "expired@example.com")
      expired_claims = %{
        "sub" => user.id,
        "role" => user.role,
        "email" => user.email,
        "type" => "access",
        "exp" => DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
        "aud" => "banking_api",
        "iss" => "ledger_bank_api"
      }

      # Use Joken directly to create expired token
      expired_token = Joken.generate_and_sign!(expired_claims)

      conn = conn
             |> put_req_header("authorization", "Bearer #{expired_token}")
             |> post(~p"/api/logout")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error with malformed authorization header", %{conn: conn} do
      conn = conn
             |> put_req_header("authorization", "InvalidFormat")
             |> post(~p"/api/logout")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "handles concurrent logouts efficiently", %{conn: conn} do
      # Create users and get access tokens
      access_tokens =
        1..@concurrent_users
        |> Task.async_stream(fn i ->
          user = insert(:user, email: "logout#{i}@example.com")
          {:ok, _user, access_token, _refresh_token} = login_user(user.email, "password123")
          access_token
        end, max_concurrency: 5, timeout: 10_000)
        |> Enum.map(fn {:ok, token} -> token end)

      start_time = System.monotonic_time(:millisecond)

      results =
        access_tokens
        |> Task.async_stream(fn access_token ->
          conn
          |> put_req_header("authorization", "Bearer #{access_token}")
          |> post(~p"/api/logout")
          |> json_response(200)
        end, max_concurrency: 5, timeout: 30_000)
        |> Enum.to_list()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # All logouts should succeed
      assert Enum.all?(results, fn {:ok, response} ->
        assert response["message"] == "Logged out successfully"
      end)

      # Performance assertion
      assert duration < @performance_threshold_ms
    end
  end

  describe "GET /api/me" do
    test "returns current user profile", %{conn: conn} do
      {_user, access_token, _refresh_token} = create_user_with_tokens()

      conn = conn
             |> put_req_header("authorization", "Bearer #{access_token}")
             |> get(~p"/api/me")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_user_response(response)
    end

    test "returns error without authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/me")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error with invalid token", %{conn: conn} do
      conn = conn
             |> put_req_header("authorization", "Bearer invalid_token")
             |> get(~p"/api/me")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error for suspended user", %{conn: conn} do
      # Create and suspend a user
      {user, access_token, _refresh_token} = create_user_with_tokens()
      suspend_user(user)

      conn = conn
             |> put_req_header("authorization", "Bearer #{access_token}")
             |> get(~p"/api/me")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "returns error with expired token", %{conn: conn} do
      {_user, _access_token, _refresh_token} = create_user_with_tokens()

      # Manually expire the access token by creating a new one with past expiration
      user = insert(:user, email: "expired@example.com")
      expired_claims = %{
        "sub" => user.id,
        "role" => user.role,
        "email" => user.email,
        "type" => "access",
        "exp" => DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
        "aud" => "banking_api",
        "iss" => "ledger_bank_api"
      }

      # Use Joken directly to create expired token
      expired_token = Joken.generate_and_sign!(expired_claims)

      conn = conn
             |> put_req_header("authorization", "Bearer #{expired_token}")
             |> get(~p"/api/me")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "handles concurrent profile requests efficiently", %{conn: conn} do
      # Create users and get access tokens
      access_tokens =
        1..@concurrent_users
        |> Task.async_stream(fn i ->
          user = insert(:user, email: "profile#{i}@example.com")
          {:ok, _user, access_token, _refresh_token} = login_user(user.email, "password123")
          access_token
        end, max_concurrency: 5, timeout: 10_000)
        |> Enum.map(fn {:ok, token} -> token end)

      start_time = System.monotonic_time(:millisecond)

      results =
        access_tokens
        |> Task.async_stream(fn access_token ->
          conn
          |> put_req_header("authorization", "Bearer #{access_token}")
          |> get(~p"/api/me")
          |> json_response(200)
        end, max_concurrency: 5, timeout: 30_000)
        |> Enum.to_list()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # All profile requests should succeed
      assert Enum.all?(results, fn {:ok, response} ->
        assert_success_response(response, 200)
        assert_user_response(response)
      end)

      # Performance assertion
      assert duration < @performance_threshold_ms
    end
  end

  describe "Admin user registration" do
    test "creates admin user when role is specified", %{conn: conn} do
      admin_attrs = Map.put(@valid_user_attrs, "role", "admin")
      conn = post(conn, ~p"/api/auth/register", user: admin_attrs)

      response = json_response(conn, 201)
      assert_success_response(response, 201)
      assert %{"data" => %{"user" => %{"role" => "admin"}}} = response
    end

    test "defaults to user role when not specified", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", user: @valid_user_attrs)

      response = json_response(conn, 201)
      assert_success_response(response, 201)
      assert %{"data" => %{"user" => %{"role" => "user"}}} = response
    end

    test "returns error for invalid role", %{conn: conn} do
      invalid_attrs = Map.put(@valid_user_attrs, "role", "invalid_role")
      conn = post(conn, ~p"/api/auth/register", user: invalid_attrs)

      response = json_response(conn, 400)
      assert_validation_error(response)
    end
  end

  describe "JWT token validation" do
    setup do
      # Create a user and get tokens
      {user, access_token, refresh_token} = create_user_with_tokens()
      %{user: user, access_token: access_token, refresh_token: refresh_token}
    end

    test "access token contains correct claims", %{user: user, access_token: access_token} do
      {:ok, claims} = LedgerBankApi.Auth.JWT.verify_token(access_token)
      assert claims["sub"] == user.id
      assert claims["email"] == user.email
      assert claims["type"] == "access"
    end

    test "refresh token contains correct claims", %{user: user, refresh_token: refresh_token} do
      {:ok, claims} = LedgerBankApi.Auth.JWT.verify_token(refresh_token)
      assert claims["sub"] == user.id
      assert claims["type"] == "refresh"
      assert claims["jti"]
    end

    test "tokens are different", %{access_token: access_token, refresh_token: refresh_token} do
      assert access_token != refresh_token
    end

    test "tokens have different expiration times", %{access_token: access_token, refresh_token: refresh_token} do
      {:ok, access_claims} = LedgerBankApi.Auth.JWT.verify_token(access_token)
      {:ok, refresh_claims} = LedgerBankApi.Auth.JWT.verify_token(refresh_token)

      # Refresh token should have longer expiration
      assert refresh_claims["exp"] > access_claims["exp"]
    end
  end

  describe "Rate limiting and security" do
    test "handles rapid successive login attempts", %{conn: conn} do
      user = insert(:user)

      # Make multiple rapid login attempts
      results = for _ <- 1..10 do
        conn
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })
        |> json_response(401)
      end

      # All should fail with unauthorized (not rate limited)
      assert Enum.all?(results, &assert_unauthorized_error/1)
    end

    test "handles rapid successive registration attempts", %{conn: conn} do
      user_attrs = build(:user)

      # Make multiple rapid registration attempts with same email
      results = for _ <- 1..5 do
        conn
        |> post(~p"/api/auth/register", user: %{
          "email" => user_attrs.email,
          "full_name" => user_attrs.full_name,
          "password" => "password123"
        })
      end

      # First should succeed, rest should fail with conflict
      [first | rest] = results
      assert json_response(first, 201)
      assert Enum.all?(rest, fn conn -> json_response(conn, 409) end)
    end
  end

  describe "Memory and resource usage" do
    test "does not leak memory during operations", %{conn: conn} do
      # Get initial memory usage
      initial_memory = :erlang.memory(:total)

      # Perform multiple operations
      1..50
      |> Task.async_stream(fn i ->
        user_data = %{
          "user" => %{
            "email" => "memory#{i}@example.com",
            "full_name" => "Memory User #{i}",
            "password" => "password123"
          }
        }

        conn
        |> post(~p"/api/auth/register", user_data)
        |> json_response(201)
      end, max_concurrency: 3, timeout: 30_000)
      |> Enum.to_list()

      # Force garbage collection
      :erlang.garbage_collect()

      # Check final memory usage
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory

      # Memory increase should be reasonable (less than 10MB)
      assert memory_increase < 10_000_000
    end
  end
end

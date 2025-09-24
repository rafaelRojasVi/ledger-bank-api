defmodule LedgerBankApiWeb.Controllers.AuthControllerTest do
  use LedgerBankApiWeb.ConnCase, async: true
  alias LedgerBankApi.UsersFixtures

  describe "POST /api/auth/login" do
    test "successfully logs in a user with valid credentials", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: "password123!"
      })

      assert %{
        "success" => true,
        "data" => %{
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "user" => %{
            "id" => _user_id,
            "email" => "test@example.com",
            "role" => "user"
          }
        }
      } = json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
    end

    test "successfully logs in an admin user with valid credentials", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "admin@example.com",
        password: "AdminPassword123!",
        password_confirmation: "AdminPassword123!",
        role: "admin"
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "admin@example.com",
        password: "AdminPassword123!"
      })

      assert %{
        "success" => true,
        "data" => %{
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "user" => %{
            "id" => _user_id,
            "email" => "admin@example.com",
            "role" => "admin"
          }
        }
      } = json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
    end

    test "fails to login with invalid email", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "wrong@example.com",
        password: "password123!"
      })

      assert %{
        "error" => %{
          "type" => "not_found",
          "reason" => "user_not_found"
        }
      } = json_response(conn, 404)
    end

    test "fails to login with invalid password", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: "wrongpassword"
      })

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_credentials"
        }
      } = json_response(conn, 401)
    end

    test "fails to login with missing fields", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com"
        # missing password
      })

      response = json_response(conn, 401)
      assert %{"error" => error} = response
      assert error["type"] == "unauthorized"
      assert error["reason"] == "invalid_credentials"
      assert error["code"] == 401
      assert error["details"]["field"] == "password"
      assert error["details"]["source"] == "input_validator"
    end

    test "fails to login with empty email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{
        email: "",
        password: "password123!"
      })

      response = json_response(conn, 400)
      assert %{"error" => error} = response
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
    end

    test "fails to login with empty password", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: ""
      })

      response = json_response(conn, 401)
      assert %{"error" => error} = response
      assert error["type"] == "unauthorized"
      assert error["reason"] == "invalid_credentials"
    end

    test "fails to login with nil email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{
        email: nil,
        password: "password123!"
      })

      response = json_response(conn, 400)
      assert %{"error" => error} = response
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
    end

    test "fails to login with nil password", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: nil
      })

      response = json_response(conn, 401)
      assert %{"error" => error} = response
      assert error["type"] == "unauthorized"
      assert error["reason"] == "invalid_credentials"
    end

    test "fails to login with inactive user", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        active: false
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: "password123!"
      })

      response = json_response(conn, 422)
      assert %{"error" => error} = response
      assert error["type"] == "unprocessable_entity"
      assert error["reason"] == "account_inactive"
    end

    test "fails to login with suspended user", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        suspended: true
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: "password123!"
      })

      response = json_response(conn, 422)
      assert %{"error" => error} = response
      assert error["type"] == "unprocessable_entity"
      assert error["reason"] == "account_inactive"
    end

    test "fails to login with case-sensitive email", %{conn: conn} do
      UsersFixtures.user_fixture(%{
        email: "Test@Example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      conn = post(conn, ~p"/api/auth/login", %{
        email: "test@example.com",
        password: "password123!"
      })

      response = json_response(conn, 404)
      assert %{"error" => error} = response
      assert error["type"] == "not_found"
      assert error["reason"] == "user_not_found"
    end
  end

  describe "POST /api/auth/refresh" do
    test "successfully refreshes access token with valid refresh token", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)

      conn = post(conn, ~p"/api/auth/refresh", %{
        refresh_token: refresh_token
      })

      assert %{
        "success" => true,
        "data" => %{
          "access_token" => %{
            "access_token" => access_token,
            "refresh_token" => refresh_token
          }
        }
      } = json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
    end

    test "fails to refresh with invalid refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{
        refresh_token: "invalid.token.here"
      })

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to refresh with missing refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{})

      response = json_response(conn, 400)
      assert %{"error" => error} = response
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
      assert error["code"] == 400
      assert error["details"]["field"] == "refresh_token"
      assert error["details"]["message"] == "Refresh token is required and must be a non-empty string"
    end

    test "fails to refresh with empty refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{
        refresh_token: ""
      })

      response = json_response(conn, 400)
      assert %{"error" => error} = response
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
      assert error["code"] == 400
      assert error["details"]["field"] == "refresh_token"
      assert error["details"]["source"] == "input_validator"
    end

    test "fails to refresh with nil refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{
        refresh_token: nil
      })

      response = json_response(conn, 400)
      assert %{"error" => error} = response
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
    end

    test "fails to refresh with revoked refresh token", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)
      {:ok, claims} = LedgerBankApi.Accounts.AuthService.verify_refresh_token(refresh_token)
      jti = claims["jti"]

      # Revoke the token
      {:ok, _} = LedgerBankApi.Accounts.UserService.revoke_refresh_token(jti)

      conn = post(conn, ~p"/api/auth/refresh", %{
        refresh_token: refresh_token
      })

      response = json_response(conn, 401)
      assert %{"error" => error} = response
      assert error["type"] == "unauthorized"
      assert error["reason"] == "token_revoked"
    end

    test "fails to refresh with expired refresh token", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      # Create an expired refresh token manually
      payload = %{
        "sub" => to_string(user.id),
        "exp" => System.system_time(:second) - 3600,  # 1 hour ago
        "iat" => System.system_time(:second) - 7200,  # 2 hours ago
        "type" => "refresh",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      expired_token = Joken.generate_and_sign!(payload, signer)

      conn = post(conn, ~p"/api/auth/refresh", %{
        refresh_token: expired_token
      })

      response = json_response(conn, 401)
      assert %{"error" => error} = response
      assert error["type"] == "unauthorized"
      assert error["reason"] == "invalid_token_type"
    end
  end

  describe "POST /api/auth/logout" do
    test "successfully logs out user with valid refresh token", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)

      conn = post(conn, ~p"/api/auth/logout", %{
        refresh_token: refresh_token
      })

      assert %{
        "success" => true,
        "data" => %{
          "message" => "Logged out successfully"
        }
      } = json_response(conn, 200)
    end

    test "fails to logout with invalid refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout", %{
        refresh_token: "invalid.token.here"
      })

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to logout with empty refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout", %{
        refresh_token: ""
      })

      assert %{
        "error" => %{
          "type" => "validation_error",
          "reason" => "missing_fields"
        }
      } = json_response(conn, 400)
    end

    test "fails to logout with nil refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout", %{
        refresh_token: nil
      })

      response = json_response(conn, 400)
      assert %{"error" => error} = response
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
    end

    test "fails to logout with missing refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout", %{})

      response = json_response(conn, 400)
      assert %{"error" => error} = response
      assert error["type"] == "validation_error"
      assert error["reason"] == "missing_fields"
    end

    test "fails to logout with already revoked refresh token", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)
      {:ok, claims} = LedgerBankApi.Accounts.AuthService.verify_refresh_token(refresh_token)
      jti = claims["jti"]

      # Revoke the token first
      {:ok, _} = LedgerBankApi.Accounts.UserService.revoke_refresh_token(jti)

      conn = post(conn, ~p"/api/auth/logout", %{
        refresh_token: refresh_token
      })

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "token_revoked"
        }
      } = json_response(conn, 401)
    end
  end

  describe "POST /api/auth/logout-all" do
    test "successfully logs out user from all devices with valid access token", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, access_token} = LedgerBankApi.Accounts.AuthService.generate_access_token(user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> post(~p"/api/auth/logout-all")

      assert %{
        "success" => true,
        "data" => %{
          "message" => "Logged out from all devices successfully"
        }
      } = json_response(conn, 200)
    end

    test "fails to logout all devices with invalid access token", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "Bearer invalid.token.here")
      |> post(~p"/api/auth/logout-all")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to logout all devices without authorization header", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout-all")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to logout all devices with empty authorization header", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "")
      |> post(~p"/api/auth/logout-all")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to logout all devices with malformed authorization header", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "InvalidFormat")
      |> post(~p"/api/auth/logout-all")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to logout all devices with expired access token", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      # Create an expired access token manually
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) - 3600,  # 1 hour ago
        "iat" => System.system_time(:second) - 7200,  # 2 hours ago
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      expired_token = Joken.generate_and_sign!(payload, signer)

      conn = conn
      |> put_req_header("authorization", "Bearer #{expired_token}")
      |> post(~p"/api/auth/logout-all")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token_type"
        }
      } = json_response(conn, 401)
    end

    test "fails to logout all devices with refresh token (wrong type)", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{refresh_token}")
      |> post(~p"/api/auth/logout-all")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token_type"
        }
      } = json_response(conn, 401)
    end
  end

  describe "GET /api/auth/me" do
    test "successfully returns current user info with valid access token", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{
        email: "test@example.com",
        full_name: "Test User"
      })
      {:ok, access_token} = LedgerBankApi.Accounts.AuthService.generate_access_token(user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> get(~p"/api/auth/me")

      assert %{
        "success" => true,
        "data" => %{
          "id" => user_id,
          "email" => "test@example.com",
          "full_name" => "Test User",
          "role" => "user",
          "status" => "ACTIVE",
          "active" => true,
          "verified" => false
        }
      } = json_response(conn, 200)

      assert user_id == user.id
    end

    test "fails to get user info with invalid access token", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "Bearer invalid.token.here")
      |> get(~p"/api/auth/me")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to get user info without authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to get user info with empty authorization header", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "")
      |> get(~p"/api/auth/me")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to get user info with malformed authorization header", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "InvalidFormat")
      |> get(~p"/api/auth/me")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to get user info with expired access token", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      # Create an expired access token manually
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) - 3600,  # 1 hour ago
        "iat" => System.system_time(:second) - 7200,  # 2 hours ago
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      expired_token = Joken.generate_and_sign!(payload, signer)

      conn = conn
      |> put_req_header("authorization", "Bearer #{expired_token}")
      |> get(~p"/api/auth/me")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token_type"
        }
      } = json_response(conn, 401)
    end

    test "fails to get user info with refresh token (wrong type)", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{refresh_token}")
      |> get(~p"/api/auth/me")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token_type"
        }
      } = json_response(conn, 401)
    end
  end

  describe "GET /api/auth/validate" do
    test "successfully validates access token", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, access_token} = LedgerBankApi.Accounts.AuthService.generate_access_token(user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> get(~p"/api/auth/validate")

      assert %{
        "success" => true,
        "data" => %{
          "valid" => true,
          "user_id" => user_id,
          "role" => "user",
          "expires_at" => _expires_at
        }
      } = json_response(conn, 200)

      assert user_id == user.id
    end

    test "fails to validate invalid access token", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "Bearer invalid.token.here")
      |> get(~p"/api/auth/validate")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to validate without authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/validate")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to validate with empty authorization header", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "")
      |> get(~p"/api/auth/validate")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to validate with malformed authorization header", %{conn: conn} do
      conn = conn
      |> put_req_header("authorization", "InvalidFormat")
      |> get(~p"/api/auth/validate")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token"
        }
      } = json_response(conn, 401)
    end

    test "fails to validate with expired access token", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      # Create an expired access token manually
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) - 3600,  # 1 hour ago
        "iat" => System.system_time(:second) - 7200,  # 2 hours ago
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      expired_token = Joken.generate_and_sign!(payload, signer)

      conn = conn
      |> put_req_header("authorization", "Bearer #{expired_token}")
      |> get(~p"/api/auth/validate")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token_type"
        }
      } = json_response(conn, 401)
    end

    test "fails to validate with refresh token (wrong type)", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{refresh_token}")
      |> get(~p"/api/auth/validate")

      assert %{
        "error" => %{
          "type" => "unauthorized",
          "reason" => "invalid_token_type"
        }
      } = json_response(conn, 401)
    end
  end
end

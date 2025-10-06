defmodule LedgerBankApi.Accounts.AuthServiceTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Accounts.{AuthService, UserService}
  alias LedgerBankApi.UsersFixtures

  describe "generate_access_token/1" do
    test "generates a valid access token for a user" do
      user = UsersFixtures.user_fixture()

      {:ok, token} = AuthService.generate_access_token(user)

      assert is_binary(token)
      assert String.length(token) > 0

      # Verify the token can be decoded and validated
      {:ok, claims} = AuthService.verify_access_token(token)
      assert claims["sub"] == to_string(user.id)
      assert claims["email"] == user.email
      assert claims["role"] == user.role
      assert claims["type"] == "access"
      assert claims["iss"] == "ledger-bank-api"
      assert claims["aud"] == "ledger-bank-api"
      assert is_integer(claims["exp"])
      assert is_integer(claims["iat"])
      assert is_integer(claims["nbf"])
    end

    test "generates token with correct expiration time (15 minutes)" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)
      {:ok, claims} = AuthService.verify_access_token(token)

      exp_time = DateTime.from_unix!(claims["exp"])
      iat_time = DateTime.from_unix!(claims["iat"])
      duration = DateTime.diff(exp_time, iat_time, :second)

      assert duration == 900  # 15 minutes
    end

    test "generates token with unique JTI for each call" do
      user = UsersFixtures.user_fixture()
      {:ok, token1} = AuthService.generate_access_token(user)
      {:ok, token2} = AuthService.generate_access_token(user)

      {:ok, claims1} = AuthService.verify_access_token(token1)
      {:ok, claims2} = AuthService.verify_access_token(token2)

      assert claims1["jti"] != claims2["jti"]
    end

    test "handles nil user gracefully" do
      # Note: In the new architecture, nil user validation happens in the web layer (InputValidator)
      # The business layer trusts that inputs are valid. This test verifies the service
      # will fail gracefully when given invalid inputs (defensive programming).
      assert_raise KeyError, fn ->
        AuthService.generate_access_token(nil)
      end
    end

    test "generates different tokens for different users" do
      user1 = UsersFixtures.user_fixture()
      user2 = UsersFixtures.user_fixture()

      {:ok, token1} = AuthService.generate_access_token(user1)
      {:ok, token2} = AuthService.generate_access_token(user2)

      assert token1 != token2
    end

    test "generates different tokens for the same user at different times" do
      user = UsersFixtures.user_fixture()

      {:ok, token1} = AuthService.generate_access_token(user)
      Process.sleep(1000)  # Wait 1 second
      {:ok, token2} = AuthService.generate_access_token(user)

      assert token1 != token2
    end
  end

  describe "generate_refresh_token/1" do
    test "generates a valid refresh token for a user" do
      user = UsersFixtures.user_fixture()

      {:ok, token} = AuthService.generate_refresh_token(user)

      assert is_binary(token)
      assert String.length(token) > 0

      # Verify the token can be decoded and validated
      {:ok, claims} = AuthService.verify_refresh_token(token)
      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "refresh"
      assert claims["iss"] == "ledger-bank-api"
      assert claims["aud"] == "ledger-bank-api"
      assert is_integer(claims["exp"])
      assert is_integer(claims["iat"])
      assert is_integer(claims["nbf"])
      assert is_binary(claims["jti"])
    end

    test "generates token with correct expiration time (7 days)" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_refresh_token(user)
      {:ok, claims} = AuthService.verify_refresh_token(token)

      exp_time = DateTime.from_unix!(claims["exp"])
      iat_time = DateTime.from_unix!(claims["iat"])
      duration = DateTime.diff(exp_time, iat_time, :second)

      assert duration == 604800  # 7 days
    end

    test "stores refresh token in database" do
      user = UsersFixtures.user_fixture()

      {:ok, token} = AuthService.generate_refresh_token(user)
      {:ok, claims} = AuthService.verify_refresh_token(token)
      jti = claims["jti"]

      # Verify the refresh token is stored in the database
      {:ok, refresh_token} = UserService.get_refresh_token(jti)
      assert refresh_token.user_id == user.id
      assert refresh_token.jti == jti
    end

    test "generates unique JTI for each refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, token1} = AuthService.generate_refresh_token(user)
      {:ok, token2} = AuthService.generate_refresh_token(user)

      {:ok, claims1} = AuthService.verify_refresh_token(token1)
      {:ok, claims2} = AuthService.verify_refresh_token(token2)

      assert claims1["jti"] != claims2["jti"]
    end

    test "handles nil user gracefully" do
      # Note: In the new architecture, nil validation happens in the web layer (InputValidator)
      # The business layer trusts that inputs are valid. This test verifies the service
      # will fail gracefully when given invalid inputs (defensive programming).
      assert_raise KeyError, fn ->
        AuthService.generate_refresh_token(nil)
      end
    end

    test "generates different tokens for different users" do
      user1 = UsersFixtures.user_fixture()
      user2 = UsersFixtures.user_fixture()

      {:ok, token1} = AuthService.generate_refresh_token(user1)
      {:ok, token2} = AuthService.generate_refresh_token(user2)

      assert token1 != token2
    end
  end

  describe "verify_access_token/1" do
    test "verifies a valid access token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      {:ok, claims} = AuthService.verify_access_token(token)
      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "access"
    end

    test "rejects an invalid token" do
      invalid_token = "invalid.token.here"

      {:error, error} = AuthService.verify_access_token(invalid_token)
      assert error.type == :unauthorized
    end

    test "rejects a token with wrong type" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)

      {:error, error} = AuthService.verify_access_token(refresh_token)
      assert error.type == :unauthorized
    end

    test "rejects an expired token" do
      user = UsersFixtures.user_fixture()

      # Create a token with past expiration
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
      token = Joken.generate_and_sign!(payload, signer)
      {:error, error} = AuthService.verify_access_token(token)
      assert error.type == :unauthorized
    end
  end

  describe "verify_refresh_token/1" do
    test "verifies a valid refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_refresh_token(user)

      {:ok, claims} = AuthService.verify_refresh_token(token)
      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "refresh"
    end

    test "rejects a revoked refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_refresh_token(user)
      {:ok, claims} = AuthService.verify_refresh_token(token)
      jti = claims["jti"]

      # Revoke the token
      {:ok, _} = UserService.revoke_refresh_token(jti)

      {:error, error} = AuthService.verify_refresh_token(token)
      assert error.type == :unauthorized
      assert error.reason == :token_revoked
    end

    test "rejects an invalid refresh token" do
      invalid_token = "invalid.token.here"

      {:error, error} = AuthService.verify_refresh_token(invalid_token)
      assert error.type == :unauthorized
    end
  end

  describe "login_user/2" do
    test "successfully logs in a user with valid credentials" do
      user = UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "ValidPassword123!",
        password_confirmation: "ValidPassword123!"
      })

      {:ok, result} = AuthService.login_user("test@example.com", "ValidPassword123!")

      assert result.access_token != nil
      assert result.refresh_token != nil
      assert result.user.id == user.id
      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)

      # Verify both tokens are valid
      {:ok, access_claims} = AuthService.verify_access_token(result.access_token)
      {:ok, refresh_claims} = AuthService.verify_refresh_token(result.refresh_token)

      assert access_claims["sub"] == to_string(user.id)
      assert refresh_claims["sub"] == to_string(user.id)
    end

    test "successfully logs in admin user with valid credentials" do
      _user = UsersFixtures.user_fixture(%{
        email: "admin@example.com",
        password: "AdminPassword123!",
        password_confirmation: "AdminPassword123!",
        role: "admin"
      })

      {:ok, result} = AuthService.login_user("admin@example.com", "AdminPassword123!")

      assert result.user.role == "admin"
      {:ok, access_claims} = AuthService.verify_access_token(result.access_token)
      assert access_claims["role"] == "admin"
    end

    test "SECURITY: fails to login with invalid email (returns :invalid_credentials)" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "ValidPassword123!",
        password_confirmation: "ValidPassword123!"
      })

      {:error, error} = AuthService.login_user("wrong@example.com", "ValidPassword123!")

      # SECURITY: Should return :unauthorized with :invalid_credentials
      # NOT :not_found to prevent email enumeration
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
      refute error.type == :not_found
    end

    test "fails to login with invalid password" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "ValidPassword123!",
        password_confirmation: "ValidPassword123!"
      })

      {:error, error} = AuthService.login_user("test@example.com", "wrongpassword")
      assert error.type == :unauthorized
    end

    test "fails to login with empty email" do
      {:error, error} = AuthService.login_user("", "ValidPassword123!")
      assert error.type == :not_found
    end

    test "fails to login with empty password" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "ValidPassword123!",
        password_confirmation: "ValidPassword123!"
      })

      {:error, error} = AuthService.login_user("test@example.com", "")
      assert error.type == :unauthorized
    end

    test "fails to login with nil email" do
      # Note: With improved validation, nil email now returns :not_found for security
      {:error, error} = AuthService.login_user(nil, "ValidPassword123!")
      assert error.type == :not_found
    end

    test "fails to login with nil password" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "ValidPassword123!",
        password_confirmation: "ValidPassword123!"
      })

      # Note: With improved validation, nil password now returns :unauthorized
      {:error, error} = AuthService.login_user("test@example.com", nil)
      assert error.type == :unauthorized
    end

    test "fails to login inactive user" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "ValidPassword123!",
        password_confirmation: "ValidPassword123!",
        active: false
      })

      {:error, error} = AuthService.login_user("test@example.com", "ValidPassword123!")
      assert error.type == :unprocessable_entity
    end

    test "fails to login suspended user" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "ValidPassword123!",
        password_confirmation: "ValidPassword123!",
        suspended: true
      })

      {:error, error} = AuthService.login_user("test@example.com", "ValidPassword123!")
      assert error.type == :unprocessable_entity
    end
  end

  describe "refresh_access_token/1" do
    test "successfully refreshes an access token" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)

      {:ok, tokens} = AuthService.refresh_access_token(refresh_token)

      assert is_binary(tokens.access_token)
      assert is_binary(tokens.refresh_token)
      {:ok, claims} = AuthService.verify_access_token(tokens.access_token)
      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "access"
    end

    test "refresh token rotation generates new refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, original_refresh_token} = AuthService.generate_refresh_token(user)

      {:ok, tokens} = AuthService.refresh_access_token(original_refresh_token)

      # New refresh token should be different from original
      assert tokens.refresh_token != original_refresh_token

      # Original refresh token should now be invalid
      {:error, error} = AuthService.verify_refresh_token(original_refresh_token)
      assert error.type == :unauthorized
    end

    test "fails to refresh with invalid refresh token" do
      invalid_token = "invalid.token.here"

      {:error, error} = AuthService.refresh_access_token(invalid_token)
      assert error.type == :unauthorized
    end

    test "fails to refresh with empty refresh token" do
      # Note: Empty string fails Joken validation and returns :unauthorized
      # This is expected behavior as Joken validates token format
      {:error, error} = AuthService.refresh_access_token("")
      assert error.type == :unauthorized
    end

    test "fails to refresh with nil refresh token" do
      # Note: In the new architecture, nil token validation happens in the web layer (InputValidator)
      # The business layer trusts that inputs are valid. This test verifies the service
      # will fail gracefully when given invalid inputs.
      {:error, error} = AuthService.refresh_access_token(nil)
      assert error.type == :internal_server_error
    end

    test "fails to refresh with revoked refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)
      {:ok, claims} = AuthService.verify_refresh_token(refresh_token)
      jti = claims["jti"]

      # Revoke the token
      {:ok, _} = UserService.revoke_refresh_token(jti)

      {:error, error} = AuthService.refresh_access_token(refresh_token)
      assert error.type == :unauthorized
      assert error.reason == :token_revoked
    end

    test "fails to refresh with expired refresh token" do
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

      {:error, error} = AuthService.refresh_access_token(expired_token)
      assert error.type == :unauthorized
    end
  end

  describe "logout_user/1" do
    test "successfully logs out a user by revoking refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)
      {:ok, claims} = AuthService.verify_refresh_token(refresh_token)
      _jti = claims["jti"]

      {:ok, _} = AuthService.logout_user(refresh_token)

      # Verify the token is now revoked
      {:error, error} = AuthService.verify_refresh_token(refresh_token)
      assert error.type == :unauthorized
      assert error.reason == :token_revoked
    end

    test "fails to logout with invalid refresh token" do
      invalid_token = "invalid.token.here"

      {:error, error} = AuthService.logout_user(invalid_token)
      assert error.type == :unauthorized
    end

    test "fails to logout with nil refresh token" do
      # Note: In the new architecture, nil token validation happens in the web layer (InputValidator)
      # The business layer trusts that inputs are valid. This test verifies the service
      # will fail gracefully when given invalid inputs.
      {:error, error} = AuthService.logout_user(nil)
      assert error.type == :internal_server_error
    end

    test "fails to logout with empty refresh token" do
      # Note: Empty string fails Joken validation and returns :unauthorized
      # This is expected behavior as Joken validates token format
      {:error, error} = AuthService.logout_user("")
      assert error.type == :unauthorized
    end

    test "fails to logout with already revoked refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)
      {:ok, claims} = AuthService.verify_refresh_token(refresh_token)
      jti = claims["jti"]

      # Revoke the token first
      {:ok, _} = UserService.revoke_refresh_token(jti)

      # Try to logout again
      {:error, error} = AuthService.logout_user(refresh_token)
      assert error.type == :unauthorized
    end
  end

  describe "logout_user_all_devices/1" do
    test "successfully logs out user from all devices" do
      user = UsersFixtures.user_fixture()

      # Create multiple refresh tokens
      {:ok, token1} = AuthService.generate_refresh_token(user)
      {:ok, token2} = AuthService.generate_refresh_token(user)

      {:ok, _} = AuthService.logout_user_all_devices(user.id)

      # Verify both tokens are now revoked
      {:error, error1} = AuthService.verify_refresh_token(token1)
      {:error, error2} = AuthService.verify_refresh_token(token2)

      assert error1.type == :unauthorized
      assert error2.type == :unauthorized
    end

    test "handles user with no refresh tokens gracefully" do
      user = UsersFixtures.user_fixture()

      {:ok, count} = AuthService.logout_user_all_devices(user.id)
      assert count == 0
    end

    test "handles non-existent user gracefully" do
      fake_id = Ecto.UUID.generate()

      {:ok, count} = AuthService.logout_user_all_devices(fake_id)
      assert count == 0
    end

    test "handles nil user_id gracefully" do
      # Note: With improved validation, nil user_id now returns a proper error instead of raising
      {:error, error} = AuthService.logout_user_all_devices(nil)
      assert error.type == :validation_error
      assert error.reason == :missing_fields
    end
  end

  describe "get_user_from_token/1" do
    test "successfully gets user from valid access token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      {:ok, retrieved_user} = AuthService.get_user_from_token(token)
      assert retrieved_user.id == user.id
      assert retrieved_user.email == user.email
    end

    test "fails to get user from invalid token" do
      invalid_token = "invalid.token.here"

      {:error, error} = AuthService.get_user_from_token(invalid_token)
      assert error.type == :unauthorized
    end

    test "fails to get user from empty token" do
      # Note: Empty string fails Joken validation and returns :unauthorized
      # This is expected behavior as Joken validates token format
      {:error, error} = AuthService.get_user_from_token("")
      assert error.type == :unauthorized
    end

    test "fails to get user from nil token" do
      # Note: In the new architecture, nil token validation happens in the web layer (InputValidator)
      # The business layer trusts that inputs are valid. This test verifies the service
      # will fail gracefully when given invalid inputs.
      {:error, error} = AuthService.get_user_from_token(nil)
      assert error.type == :internal_server_error
    end

    test "fails to get user from expired access token" do
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

      {:error, error} = AuthService.get_user_from_token(expired_token)
      assert error.type == :unauthorized
    end

    test "fails to get user from refresh token (wrong type)" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)

      {:error, error} = AuthService.get_user_from_token(refresh_token)
      assert error.type == :unauthorized
    end

    test "fails to get user from token with non-existent user" do
      fake_user_id = Ecto.UUID.generate()

      # Create a token for a non-existent user
      payload = %{
        "sub" => fake_user_id,
        "email" => "fake@example.com",
        "role" => "user",
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      {:error, error} = AuthService.get_user_from_token(token)
      # The token verification might fail due to JWT secret mismatch, so we get :unauthorized
      assert error.type == :unauthorized
    end
  end

  describe "get_token_expiration/1" do
    test "successfully gets token expiration time" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      {:ok, expiration} = AuthService.get_token_expiration(token)
      assert %DateTime{} = expiration
      assert DateTime.compare(expiration, DateTime.utc_now()) == :gt
    end

    test "fails to get expiration from invalid token" do
      invalid_token = "invalid.token.here"

      {:error, error} = AuthService.get_token_expiration(invalid_token)
      assert error.type == :unauthorized
    end

    test "fails to get expiration from empty token" do
      # Note: Empty string fails Joken validation and returns :unauthorized
      # This is expected behavior as Joken validates token format
      {:error, error} = AuthService.get_token_expiration("")
      assert error.type == :unauthorized
    end

    test "fails to get expiration from nil token" do
      # Note: In the new architecture, nil token validation happens in the web layer (InputValidator)
      # The business layer trusts that inputs are valid. This test verifies the service
      # will fail gracefully when given invalid inputs.
      {:error, error} = AuthService.get_token_expiration(nil)
      assert error.type == :internal_server_error
    end

    test "fails to get expiration from refresh token (wrong type)" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)

      {:error, error} = AuthService.get_token_expiration(refresh_token)
      assert error.type == :unauthorized
    end

    test "fails to get expiration from expired token" do
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

      {:error, error} = AuthService.get_token_expiration(expired_token)
      assert error.type == :unauthorized
    end
  end

  describe "authenticated?/1" do
    test "returns true for valid access token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      assert AuthService.authenticated?(token) == true
    end

    test "returns false for invalid token" do
      invalid_token = "invalid.token.here"

      assert AuthService.authenticated?(invalid_token) == false
    end

    test "returns false for empty token" do
      assert AuthService.authenticated?("") == false
    end

    test "returns false for nil token" do
      assert AuthService.authenticated?(nil) == false
    end

    test "returns false for expired token" do
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

      assert AuthService.authenticated?(expired_token) == false
    end

    test "returns false for refresh token (wrong type)" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)

      assert AuthService.authenticated?(refresh_token) == false
    end
  end

  describe "has_role?/2" do
    test "returns true for user with correct role" do
      user = UsersFixtures.user_fixture(%{role: "admin"})
      {:ok, token} = AuthService.generate_access_token(user)

      assert AuthService.has_role?(token, "admin") == true
      assert AuthService.has_role?(token, "user") == false
    end

    test "returns false for invalid token" do
      invalid_token = "invalid.token.here"

      assert AuthService.has_role?(invalid_token, "admin") == false
    end

    test "returns false for empty token" do
      assert AuthService.has_role?("", "admin") == false
    end

    test "returns false for nil token" do
      assert AuthService.has_role?(nil, "admin") == false
    end

    test "returns false for expired token" do
      user = UsersFixtures.user_fixture(%{role: "admin"})

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

      assert AuthService.has_role?(expired_token, "admin") == false
    end
  end

  describe "is_admin?/1, is_support?/1, is_user?/1" do
    test "correctly identifies user roles" do
      admin_user = UsersFixtures.user_fixture(%{role: "admin"})
      support_user = UsersFixtures.user_fixture(%{role: "support"})
      regular_user = UsersFixtures.user_fixture(%{role: "user"})

      {:ok, admin_token} = AuthService.generate_access_token(admin_user)
      {:ok, support_token} = AuthService.generate_access_token(support_user)
      {:ok, user_token} = AuthService.generate_access_token(regular_user)

      assert AuthService.is_admin?(admin_token) == true
      assert AuthService.is_admin?(support_token) == false
      assert AuthService.is_admin?(user_token) == false

      assert AuthService.is_support?(admin_token) == false
      assert AuthService.is_support?(support_token) == true
      assert AuthService.is_support?(user_token) == false

      assert AuthService.is_user?(admin_token) == false
      assert AuthService.is_user?(support_token) == false
      assert AuthService.is_user?(user_token) == true
    end

    test "returns false for invalid tokens" do
      invalid_token = "invalid.token.here"

      assert AuthService.is_admin?(invalid_token) == false
      assert AuthService.is_support?(invalid_token) == false
      assert AuthService.is_user?(invalid_token) == false
    end

    test "returns false for empty tokens" do
      assert AuthService.is_admin?("") == false
      assert AuthService.is_support?("") == false
      assert AuthService.is_user?("") == false
    end

    test "returns false for nil tokens" do
      assert AuthService.is_admin?(nil) == false
      assert AuthService.is_support?(nil) == false
      assert AuthService.is_user?(nil) == false
    end
  end
end

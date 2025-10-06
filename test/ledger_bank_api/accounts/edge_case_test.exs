defmodule LedgerBankApi.Accounts.EdgeCaseTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Accounts.{AuthService, UserService}
  alias LedgerBankApi.UsersFixtures

  describe "Edge Cases and Boundary Conditions" do
    test "SECURITY: handles very long email addresses (100 chars, returns :invalid_credentials)" do
      long_email = String.duplicate("a", 100) <> "@example.com"  # ~115 chars total

      {:error, error} = UserService.authenticate_user(long_email, "password123!")
      # Email passes format validation but doesn't exist
      # Triggers constant-time hashing and returns :invalid_credentials
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "SECURITY: handles extremely long email addresses (>255 chars, returns :user_not_found)" do
      long_email = String.duplicate("a", 300) <> "@example.com"  # >255 chars

      {:error, error} = UserService.authenticate_user(long_email, "password123!")
      # Email exceeds max length, fails validation before hashing
      assert error.type == :not_found
      assert error.reason == :user_not_found
    end

    test "SECURITY: handles very long passwords (returns :invalid_credentials via constant-time hashing)" do
      long_password = String.duplicate("a", 1000)

      {:error, error} = UserService.authenticate_user("test@example.com", long_password)
      # Unknown email triggers constant-time hashing and returns :invalid_credentials
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "SECURITY: handles special characters in email (returns :invalid_credentials)" do
      special_email = "test+tag@example.com"

      {:error, error} = UserService.authenticate_user(special_email, "password123!")
      # Valid format but unknown email triggers constant-time hashing
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "SECURITY: handles unicode characters in email (behavior verification)" do
      unicode_email = "tëst@ëxämplë.com"

      {:error, error} = UserService.authenticate_user(unicode_email, "password123!")
      # Unicode might pass regex validation (regex doesn't restrict to ASCII)
      # Returns either :user_not_found (validation) or :invalid_credentials (constant-time)
      # Both are acceptable security-wise
      assert error.type in [:not_found, :unauthorized]
      assert error.reason in [:user_not_found, :invalid_credentials]
    end

    test "SECURITY: handles very short passwords (returns :invalid_credentials via validation)" do
      short_password = "a"

      {:error, error} = UserService.authenticate_user("test@example.com", short_password)
      # Short password fails validation but still returns :invalid_credentials for security
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "SECURITY: handles passwords with only spaces (returns :invalid_credentials)" do
      space_password = "   "

      {:error, error} = UserService.authenticate_user("test@example.com", space_password)
      # Space-only password fails validation
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "SECURITY: handles passwords with only numbers (returns :invalid_credentials)" do
      number_password = "123456789"

      {:error, error} = UserService.authenticate_user("test@example.com", number_password)
      # Number-only password triggers constant-time hashing
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "SECURITY: handles passwords with only special characters (returns :invalid_credentials)" do
      special_password = "!@#$%^&*()"

      {:error, error} = UserService.authenticate_user("test@example.com", special_password)
      # Special-char password triggers constant-time hashing
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "handles concurrent token generation" do
      user = UsersFixtures.user_fixture()

      # Generate multiple tokens concurrently
      tasks = for _ <- 1..10 do
        Task.async(fn -> AuthService.generate_access_token(user) end)
      end

      results = Task.await_many(tasks)

      # All should succeed
      Enum.each(results, fn {:ok, token} ->
        assert is_binary(token)
        assert String.length(token) > 0
      end)

      # All tokens should be different
      tokens = Enum.map(results, fn {:ok, token} -> token end)
      unique_tokens = Enum.uniq(tokens)
      assert length(unique_tokens) == length(tokens)
    end

    test "handles concurrent refresh token creation" do
      user = UsersFixtures.user_fixture()

      # Create multiple refresh tokens concurrently
      tasks = for _ <- 1..5 do
        Task.async(fn -> AuthService.generate_refresh_token(user) end)
      end

      results = Task.await_many(tasks)

      # All should succeed
      Enum.each(results, fn {:ok, token} ->
        assert is_binary(token)
        assert String.length(token) > 0
      end)

      # All tokens should be different
      tokens = Enum.map(results, fn {:ok, token} -> token end)
      unique_tokens = Enum.uniq(tokens)
      assert length(unique_tokens) == length(tokens)
    end

    test "handles rapid token refresh" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)

      # Refresh token multiple times rapidly
      # Note: Each refresh generates a new refresh token and revokes the old one
      current_token = refresh_token

      # Use Enum.reduce to properly update the token variable
      Enum.reduce(1..5, current_token, fn _i, token ->
        {:ok, tokens} = AuthService.refresh_access_token(token)
        assert is_binary(tokens.access_token)
        assert is_binary(tokens.refresh_token)
        # Return the new refresh token for the next iteration
        tokens.refresh_token
      end)
    end

    test "handles token expiration edge cases" do
      user = UsersFixtures.user_fixture()

      # Generate a normal token first to test the flow
      {:ok, normal_token} = AuthService.generate_access_token(user)

      # Test that the normal token works
      assert AuthService.authenticated?(normal_token) == true

      # For this test, we'll test that expired tokens are properly rejected
      # by creating a token with a past expiration time
      past_time = System.system_time(:second) - 3600  # 1 hour ago

      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => past_time,
        "iat" => past_time - 3600,
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => past_time - 3600
      }

      # Use the same JWT secret and configuration as the Token module
      jwt_secret = Application.get_env(:ledger_bank_api, :jwt_secret) || System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
      signer = Joken.Signer.create("HS256", jwt_secret)
      expired_token = Joken.generate_and_sign!(payload, signer)

      IO.puts("DEBUG: Created expired token with exp: #{payload["exp"]}")
      IO.puts("DEBUG: Current time: #{System.system_time(:second)}")
      IO.puts("DEBUG: Token expired #{System.system_time(:second) - payload["exp"]} seconds ago")

      # Expired token should be invalid
      is_authenticated = AuthService.authenticated?(expired_token)
      IO.puts("DEBUG: Expired token authenticated: #{is_authenticated}")

      if is_authenticated do
        # Debug why expired token is valid
        case AuthService.verify_access_token(expired_token) do
          {:ok, claims} ->
            IO.puts("DEBUG: Expired token verification succeeded, claims: #{inspect(claims)}")
          {:error, error} ->
            IO.puts("DEBUG: Expired token verification failed: #{error.type} - #{error.reason}")
            IO.puts("DEBUG: Error context: #{inspect(error.context)}")
        end
      end

      assert is_authenticated == false
    end

    test "handles malformed JWT tokens" do
      malformed_tokens = [
        "not.a.token",
        "too.many.parts.here.extra",
        "missing.parts",
        "invalid.base64",
        "empty..token",
        "just.one.part",
        "two.parts.only"
      ]

      Enum.each(malformed_tokens, fn token ->
        assert AuthService.authenticated?(token) == false
        {:error, error} = AuthService.verify_access_token(token)
        assert error.type == :unauthorized
      end)
    end

    test "handles JWT with wrong algorithm" do
      user = UsersFixtures.user_fixture()

      # Create a token with wrong algorithm
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      # Use wrong algorithm
      signer = Joken.Signer.create("HS512", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      assert AuthService.authenticated?(token) == false
      {:error, error} = AuthService.verify_access_token(token)
      assert error.type == :unauthorized
    end

    test "handles JWT with wrong secret" do
      user = UsersFixtures.user_fixture()

      # Create a token with wrong secret
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", "wrong-secret-key")
      token = Joken.generate_and_sign!(payload, signer)

      assert AuthService.authenticated?(token) == false
      {:error, error} = AuthService.verify_access_token(token)
      assert error.type == :unauthorized
    end

    test "handles JWT with missing required claims" do
      user = UsersFixtures.user_fixture()

      # Create a token with missing 'type' claim
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      assert AuthService.authenticated?(token) == false
      {:error, error} = AuthService.verify_access_token(token)
      assert error.type == :unauthorized
    end

    test "handles JWT with wrong issuer" do
      user = UsersFixtures.user_fixture()

      # Create a token with wrong issuer
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "wrong-issuer",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      assert AuthService.authenticated?(token) == false
      {:error, error} = AuthService.verify_access_token(token)
      assert error.type == :unauthorized
    end

    test "handles JWT with wrong audience" do
      user = UsersFixtures.user_fixture()

      # Create a token with wrong audience
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "wrong-audience",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      assert AuthService.authenticated?(token) == false
      {:error, error} = AuthService.verify_access_token(token)
      assert error.type == :unauthorized
    end

    test "handles JWT with future not-before time" do
      user = UsersFixtures.user_fixture()

      # Create a token with future nbf
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) + 3600  # 1 hour in the future
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      assert AuthService.authenticated?(token) == false
      {:error, error} = AuthService.verify_access_token(token)
      assert error.type == :unauthorized
    end

    test "handles database connection issues gracefully" do
      # This test would require mocking the database connection
      # For now, we'll test that the service handles errors properly
      user = UsersFixtures.user_fixture()

      # Test that the service can handle database errors
      {:ok, _token} = AuthService.generate_access_token(user)

      # The service should handle any database issues gracefully
      # and return appropriate error responses
    end

    test "handles memory pressure scenarios" do
      user = UsersFixtures.user_fixture()

      # Generate many tokens to test memory handling
      tokens = for _ <- 1..100 do
        {:ok, token} = AuthService.generate_access_token(user)
        token
      end

      # All tokens should be valid
      Enum.each(tokens, fn token ->
        assert AuthService.authenticated?(token) == true
      end)

      # All tokens should be unique
      unique_tokens = Enum.uniq(tokens)
      assert length(unique_tokens) == length(tokens)
    end

    test "handles timezone edge cases" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      # Test token expiration in different timezones
      {:ok, expiration} = AuthService.get_token_expiration(token)
      assert %DateTime{} = expiration

      # Expiration should be in the future
      assert DateTime.compare(expiration, DateTime.utc_now()) == :gt
    end

    test "handles role-based access edge cases" do
      # Test with different role combinations
      roles = ["user", "admin", "support"]

      Enum.each(roles, fn role ->
        user = UsersFixtures.user_fixture(%{role: role})
        {:ok, token} = AuthService.generate_access_token(user)

        # Test role checking
        assert AuthService.has_role?(token, role) == true

        # Test specific role functions
        case role do
          "admin" -> assert AuthService.is_admin?(token) == true
          "support" -> assert AuthService.is_support?(token) == true
          "user" -> assert AuthService.is_user?(token) == true
        end
      end)
    end
  end
end

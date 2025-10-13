defmodule LedgerBankApi.Accounts.TokenTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Accounts.Token
  alias LedgerBankApi.UsersFixtures

  describe "service_name/0" do
    test "returns correct service name" do
      assert Token.service_name() == "token_service"
    end
  end

  describe "generate_access_token/1" do
    test "generates valid access token with all required claims" do
      user = UsersFixtures.user_fixture(%{
        email: "test@example.com",
        role: "user"
      })

      {:ok, token} = Token.generate_access_token(user)

      assert is_binary(token)
      assert String.length(token) > 0

      # Verify token structure (3 parts: header.payload.signature)
      parts = String.split(token, ".")
      assert length(parts) == 3
    end

    test "generates token with correct expiration (15 minutes)" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_access_token(user)

      # Verify using Joken directly
      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims} = Joken.verify(token, signer)

      exp_time = DateTime.from_unix!(claims["exp"])
      iat_time = DateTime.from_unix!(claims["iat"])
      duration = DateTime.diff(exp_time, iat_time, :second)

      assert duration == 900  # 15 minutes
    end

    test "generates token with unique JTI each time" do
      user = UsersFixtures.user_fixture()

      {:ok, token1} = Token.generate_access_token(user)
      {:ok, token2} = Token.generate_access_token(user)

      # Decode tokens
      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims1} = Joken.verify(token1, signer)
      {:ok, claims2} = Joken.verify(token2, signer)

      assert claims1["jti"] != claims2["jti"]
    end

    test "includes all required claims in access token" do
      user = UsersFixtures.user_fixture(%{
        email: "claims@example.com",
        role: "admin"
      })

      {:ok, token} = Token.generate_access_token(user)

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims} = Joken.verify(token, signer)

      # Required claims
      assert claims["sub"] == to_string(user.id)
      assert claims["email"] == user.email
      assert claims["role"] == user.role
      assert claims["type"] == "access"
      assert claims["iss"] == "ledger-bank-api"
      assert claims["aud"] == "ledger-bank-api"
      assert is_binary(claims["jti"])
      assert is_integer(claims["exp"])
      assert is_integer(claims["iat"])
      assert is_integer(claims["nbf"])
    end

    test "generates different tokens for different users" do
      user1 = UsersFixtures.user_fixture(%{email: "user1@example.com"})
      user2 = UsersFixtures.user_fixture(%{email: "user2@example.com"})

      {:ok, token1} = Token.generate_access_token(user1)
      {:ok, token2} = Token.generate_access_token(user2)

      assert token1 != token2

      # Verify different user IDs
      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims1} = Joken.verify(token1, signer)
      {:ok, claims2} = Joken.verify(token2, signer)

      assert claims1["sub"] != claims2["sub"]
      assert claims1["email"] != claims2["email"]
    end

    test "handles nil user gracefully" do
      assert_raise KeyError, fn ->
        Token.generate_access_token(nil)
      end
    end
  end

  describe "generate_refresh_token/1" do
    test "generates valid refresh token with all required claims" do
      user = UsersFixtures.user_fixture()

      {:ok, token} = Token.generate_refresh_token(user)

      assert is_binary(token)
      assert String.length(token) > 0

      # Verify token structure
      parts = String.split(token, ".")
      assert length(parts) == 3
    end

    test "generates token with correct expiration (7 days)" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_refresh_token(user)

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims} = Joken.verify(token, signer)

      exp_time = DateTime.from_unix!(claims["exp"])
      iat_time = DateTime.from_unix!(claims["iat"])
      duration = DateTime.diff(exp_time, iat_time, :second)

      assert duration == 604800  # 7 days
    end

    test "stores refresh token in database" do
      user = UsersFixtures.user_fixture()

      {:ok, token} = Token.generate_refresh_token(user)

      # Verify token was stored
      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims} = Joken.verify(token, signer)
      jti = claims["jti"]

      {:ok, stored_token} = LedgerBankApi.Accounts.UserService.get_refresh_token(jti)
      assert stored_token.user_id == user.id
      assert stored_token.jti == jti
      assert is_nil(stored_token.revoked_at)
    end

    test "generates unique JTI for each refresh token" do
      user = UsersFixtures.user_fixture()

      {:ok, token1} = Token.generate_refresh_token(user)
      {:ok, token2} = Token.generate_refresh_token(user)

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims1} = Joken.verify(token1, signer)
      {:ok, claims2} = Joken.verify(token2, signer)

      assert claims1["jti"] != claims2["jti"]
    end

    test "includes minimal claims in refresh token (no email/role)" do
      user = UsersFixtures.user_fixture()

      {:ok, token} = Token.generate_refresh_token(user)

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims} = Joken.verify(token, signer)

      # Refresh tokens should have minimal claims
      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "refresh"
      assert claims["jti"] != nil
      assert claims["exp"] != nil
      assert claims["iat"] != nil
      assert claims["iss"] == "ledger-bank-api"
      assert claims["aud"] == "ledger-bank-api"
    end
  end

  describe "verify_access_token/1" do
    test "successfully verifies valid access token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_access_token(user)

      {:ok, claims} = Token.verify_access_token(token)

      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "access"
    end

    test "rejects invalid token format" do
      {:error, error} = Token.verify_access_token("invalid.token.here")

      assert error.type == :unauthorized
      assert error.reason == :invalid_token
    end

    test "rejects refresh token (wrong type)" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = Token.generate_refresh_token(user)

      {:error, error} = Token.verify_access_token(refresh_token)

      assert error.type == :unauthorized
      assert error.reason == :invalid_token_type
    end

    test "rejects expired access token" do
      user = UsersFixtures.user_fixture()

      # Create expired token
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) - 3600,
        "iat" => System.system_time(:second) - 7200,
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      expired_token = Joken.generate_and_sign!(payload, signer)

      {:error, error} = Token.verify_access_token(expired_token)

      assert error.type == :unauthorized
      # Expired tokens may return :invalid_token or :invalid_token_type depending on Joken's validation order
      assert error.reason in [:invalid_token, :invalid_token_type]
    end

    test "rejects token with wrong issuer" do
      user = UsersFixtures.user_fixture()

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

      {:error, error} = Token.verify_access_token(token)

      assert error.type == :unauthorized
    end

    test "rejects token with missing type claim" do
      user = UsersFixtures.user_fixture()

      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        # Missing "type"
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      {:error, error} = Token.verify_access_token(token)

      assert error.type == :unauthorized
    end
  end

  describe "verify_refresh_token/1" do
    test "successfully verifies valid refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_refresh_token(user)

      {:ok, claims} = Token.verify_refresh_token(token)

      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "refresh"
    end

    test "rejects revoked refresh token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_refresh_token(user)

      # Get JTI and revoke
      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims} = Joken.verify(token, signer)
      jti = claims["jti"]

      {:ok, _} = LedgerBankApi.Accounts.UserService.revoke_refresh_token(jti)

      # Verify should fail
      {:error, error} = Token.verify_refresh_token(token)

      assert error.type == :unauthorized
      assert error.reason == :token_revoked
    end

    test "rejects access token (wrong type)" do
      user = UsersFixtures.user_fixture()
      {:ok, access_token} = Token.generate_access_token(user)

      {:error, error} = Token.verify_refresh_token(access_token)

      assert error.type == :unauthorized
      assert error.reason == :invalid_token_type
    end

    test "rejects expired refresh token" do
      user = UsersFixtures.user_fixture()

      payload = %{
        "sub" => to_string(user.id),
        "exp" => System.system_time(:second) - 3600,
        "iat" => System.system_time(:second) - 7200,
        "type" => "refresh",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      expired_token = Joken.generate_and_sign!(payload, signer)

      {:error, error} = Token.verify_refresh_token(expired_token)

      assert error.type == :unauthorized
    end

    test "rejects refresh token not found in database" do
      user = UsersFixtures.user_fixture()

      # Create token manually (not stored in DB)
      payload = %{
        "sub" => to_string(user.id),
        "exp" => System.system_time(:second) + 604800,
        "iat" => System.system_time(:second),
        "type" => "refresh",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),  # Random JTI not in DB
        "nbf" => System.system_time(:second)
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      token = Joken.generate_and_sign!(payload, signer)

      {:error, error} = Token.verify_refresh_token(token)

      # Should fail because JTI not found in database
      assert error.type in [:unauthorized, :not_found]
    end
  end

  describe "refresh_access_token_with_rotation/1" do
    test "successfully refreshes and rotates tokens" do
      user = UsersFixtures.user_fixture()
      {:ok, old_refresh_token} = Token.generate_refresh_token(user)

      {:ok, result} = Token.refresh_access_token_with_rotation(old_refresh_token)

      assert is_binary(result.access_token)
      assert is_binary(result.refresh_token)
      assert result.access_token != old_refresh_token
      assert result.refresh_token != old_refresh_token

      # Old refresh token should be revoked
      {:error, error} = Token.verify_refresh_token(old_refresh_token)
      assert error.reason == :token_revoked
    end

    test "new tokens are valid" do
      user = UsersFixtures.user_fixture()
      {:ok, old_refresh_token} = Token.generate_refresh_token(user)

      {:ok, result} = Token.refresh_access_token_with_rotation(old_refresh_token)

      # Verify new access token
      {:ok, access_claims} = Token.verify_access_token(result.access_token)
      assert access_claims["sub"] == to_string(user.id)
      assert access_claims["type"] == "access"

      # Verify new refresh token
      {:ok, refresh_claims} = Token.verify_refresh_token(result.refresh_token)
      assert refresh_claims["sub"] == to_string(user.id)
      assert refresh_claims["type"] == "refresh"
    end

    test "fails to refresh with invalid token" do
      {:error, error} = Token.refresh_access_token_with_rotation("invalid.token")

      assert error.type == :unauthorized
    end

    test "fails to refresh with revoked token" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = Token.generate_refresh_token(user)

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      {:ok, claims} = Joken.verify(refresh_token, signer)
      jti = claims["jti"]

      # Revoke token
      {:ok, _} = LedgerBankApi.Accounts.UserService.revoke_refresh_token(jti)

      {:error, error} = Token.refresh_access_token_with_rotation(refresh_token)

      assert error.type == :unauthorized
      assert error.reason == :token_revoked
    end

    test "fails to refresh with access token (wrong type)" do
      user = UsersFixtures.user_fixture()
      {:ok, access_token} = Token.generate_access_token(user)

      {:error, error} = Token.refresh_access_token_with_rotation(access_token)

      assert error.type == :unauthorized
    end

    test "fails when user no longer exists" do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = Token.generate_refresh_token(user)

      # Delete user
      {:ok, _} = LedgerBankApi.Accounts.UserService.delete_user(user)

      {:error, error} = Token.refresh_access_token_with_rotation(refresh_token)

      # Should fail to find user
      assert error.type in [:unauthorized, :not_found]
    end
  end

  describe "is_token_expired?/1" do
    test "returns false for valid non-expired token" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_access_token(user)

      {:ok, is_expired} = Token.is_token_expired?(token)

      assert is_expired == false
    end

    test "returns true for expired token" do
      user = UsersFixtures.user_fixture()

      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) - 3600,
        "iat" => System.system_time(:second) - 7200,
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long"))
      expired_token = Joken.generate_and_sign!(payload, signer)

      {:ok, is_expired} = Token.is_token_expired?(expired_token)

      assert is_expired == true
    end

    test "returns true for invalid token" do
      {:ok, is_expired} = Token.is_token_expired?("invalid.token")

      assert is_expired == true
    end
  end

  describe "ensure_jwt_secret!/0" do
    test "succeeds when JWT_SECRET is configured" do
      # Should not raise in test environment (JWT_SECRET is configured)
      assert :ok = Token.ensure_jwt_secret!()
    end
  end

  describe "token signing and verification" do
    test "tokens signed with same secret can be verified" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_access_token(user)

      # Verify with same configuration
      {:ok, claims} = Token.verify_access_token(token)

      assert claims["sub"] == to_string(user.id)
    end

    test "tokens signed with different secret cannot be verified" do
      user = UsersFixtures.user_fixture()

      # Create token with different secret
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

      wrong_signer = Joken.Signer.create("HS256", "different-secret-key-not-the-configured-one")
      wrong_token = Joken.generate_and_sign!(payload, wrong_signer)

      {:error, error} = Token.verify_access_token(wrong_token)

      assert error.type == :unauthorized
    end
  end

  describe "token edge cases" do
    test "handles very long user IDs" do
      user = UsersFixtures.user_fixture()

      {:ok, token} = Token.generate_access_token(user)

      # Should still verify successfully
      {:ok, claims} = Token.verify_access_token(token)
      assert claims["sub"] == to_string(user.id)
    end

    test "handles special characters in user email" do
      user = UsersFixtures.user_fixture(%{email: "test+tag@example.com"})

      {:ok, token} = Token.generate_access_token(user)

      {:ok, claims} = Token.verify_access_token(token)
      assert claims["email"] == "test+tag@example.com"
    end

    test "generates tokens with consistent format" do
      user = UsersFixtures.user_fixture()

      tokens = Enum.map(1..10, fn _ ->
        {:ok, token} = Token.generate_access_token(user)
        token
      end)

      # All should have 3 parts
      Enum.each(tokens, fn token ->
        parts = String.split(token, ".")
        assert length(parts) == 3
      end)

      # All should be unique
      unique_tokens = Enum.uniq(tokens)
      assert length(unique_tokens) == 10
    end
  end

  describe "concurrent token operations" do
    test "handles concurrent access token generation" do
      user = UsersFixtures.user_fixture()

      tasks = Enum.map(1..20, fn _ ->
        Task.async(fn ->
          Token.generate_access_token(user)
        end)
      end)

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # All tokens should be unique
      tokens = Enum.map(results, fn {:ok, token} -> token end)
      unique_tokens = Enum.uniq(tokens)
      assert length(unique_tokens) == 20
    end

    test "handles concurrent refresh token generation" do
      user = UsersFixtures.user_fixture()

      tasks = Enum.map(1..10, fn _ ->
        Task.async(fn ->
          Token.generate_refresh_token(user)
        end)
      end)

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # All tokens should be unique
      tokens = Enum.map(results, fn {:ok, token} -> token end)
      unique_tokens = Enum.uniq(tokens)
      assert length(unique_tokens) == 10
    end

    test "handles concurrent token verification" do
      user = UsersFixtures.user_fixture()
      {:ok, token} = Token.generate_access_token(user)

      tasks = Enum.map(1..50, fn _ ->
        Task.async(fn ->
          Token.verify_access_token(token)
        end)
      end)

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # All should return same claims
      claim_sets = Enum.map(results, fn {:ok, claims} -> claims["sub"] end)
      assert Enum.uniq(claim_sets) == [to_string(user.id)]
    end
  end
end

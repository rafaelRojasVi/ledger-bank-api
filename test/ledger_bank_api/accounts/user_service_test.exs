defmodule LedgerBankApi.Accounts.UserServiceTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Accounts.UserService
  alias LedgerBankApi.UsersFixtures

  describe "authenticate_user/2" do
    test "successfully authenticates user with valid credentials" do
      user = UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      {:ok, authenticated_user} = UserService.authenticate_user("test@example.com", "password123!")
      assert authenticated_user.id == user.id
      assert authenticated_user.email == user.email
    end

    test "successfully authenticates admin user with valid credentials" do
      user = UsersFixtures.user_fixture(%{
        email: "admin@example.com",
        password: "AdminPassword123!",
        password_confirmation: "AdminPassword123!",
        role: "admin"
      })

      {:ok, authenticated_user} = UserService.authenticate_user("admin@example.com", "AdminPassword123!")
      assert authenticated_user.id == user.id
      assert authenticated_user.role == "admin"
    end

    test "fails to authenticate with invalid email" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      {:error, error} = UserService.authenticate_user("wrong@example.com", "password123!")
      assert error.type == :not_found
      assert error.reason == :user_not_found
    end

    test "fails to authenticate with invalid password" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      {:error, error} = UserService.authenticate_user("test@example.com", "wrongpassword")
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "fails to authenticate with empty email" do
      {:error, error} = UserService.authenticate_user("", "password123!")
      assert error.type == :not_found
      assert error.reason == :user_not_found
    end

    test "fails to authenticate with empty password" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      {:error, error} = UserService.authenticate_user("test@example.com", "")
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "fails to authenticate with nil email" do
      {:error, error} = UserService.authenticate_user(nil, "password123!")
      assert error.type == :not_found
      assert error.reason == :user_not_found
    end

    test "fails to authenticate with nil password" do
      UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      {:error, error} = UserService.authenticate_user("test@example.com", nil)
      assert error.type == :unauthorized
      assert error.reason == :invalid_credentials
    end

    test "fails to authenticate inactive user" do
      _user = UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        active: false
      })

      {:error, error} = UserService.authenticate_user("test@example.com", "password123!")
      assert error.type == :unprocessable_entity
      assert error.reason == :account_inactive
    end

    test "fails to authenticate suspended user" do
      _user = UsersFixtures.user_fixture(%{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        suspended: true
      })

      {:error, error} = UserService.authenticate_user("test@example.com", "password123!")
      assert error.type == :unprocessable_entity
      assert error.reason == :account_inactive
    end

    test "fails to authenticate user with case-sensitive email" do
      UsersFixtures.user_fixture(%{
        email: "Test@Example.com",
        password: "password123!",
        password_confirmation: "password123!"
      })

      {:error, error} = UserService.authenticate_user("test@example.com", "password123!")
      assert error.type == :not_found
      assert error.reason == :user_not_found
    end
  end

  describe "get_user/1" do
    test "successfully retrieves user by id" do
      user = UsersFixtures.user_fixture()

      {:ok, retrieved_user} = UserService.get_user(user.id)
      assert retrieved_user.id == user.id
      assert retrieved_user.email == user.email
    end

    test "successfully retrieves admin user by id" do
      user = UsersFixtures.user_fixture(%{role: "admin"})

      {:ok, retrieved_user} = UserService.get_user(user.id)
      assert retrieved_user.id == user.id
      assert retrieved_user.role == "admin"
    end

    test "fails to retrieve non-existent user" do
      fake_id = Ecto.UUID.generate()

      {:error, error} = UserService.get_user(fake_id)
      assert error.type == :not_found
      assert error.reason == :user_not_found
    end

    test "fails to retrieve user with invalid UUID" do
      {:error, error} = UserService.get_user("invalid-uuid")
      assert error.type == :validation_error
    end

    test "fails to retrieve user with nil id" do
      {:error, error} = UserService.get_user(nil)
      assert error.type == :validation_error
    end

    test "fails to retrieve user with empty string id" do
      {:error, error} = UserService.get_user("")
      assert error.type == :validation_error
    end
  end

  describe "create_refresh_token/1" do
    test "successfully creates a refresh token" do
      user = UsersFixtures.user_fixture()
      jti = Ecto.UUID.generate()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, refresh_token} = UserService.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: expires_at
      })

      assert refresh_token.jti == jti
      assert refresh_token.user_id == user.id
      # Compare datetime with 1 second tolerance for microsecond precision
      assert DateTime.diff(refresh_token.expires_at, expires_at, :second) < 1
      assert LedgerBankApi.Accounts.Schemas.RefreshToken.revoked?(refresh_token) == false
    end

    test "fails to create refresh token with invalid data" do
      {:error, error} = UserService.create_refresh_token(%{})
      assert error.type == :validation_error
      assert error.reason == :missing_fields
    end

    test "fails to create refresh token with invalid user_id" do
      jti = Ecto.UUID.generate()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:error, error} = UserService.create_refresh_token(%{
        jti: jti,
        user_id: "invalid-uuid",
        expires_at: expires_at
      })
      assert error.type == :validation_error
    end

    test "fails to create refresh token with non-existent user_id" do
      jti = Ecto.UUID.generate()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)
      fake_user_id = Ecto.UUID.generate()

      {:error, error} = UserService.create_refresh_token(%{
        jti: jti,
        user_id: fake_user_id,
        expires_at: expires_at
      })
      assert error.type == :validation_error
    end

    test "fails to create refresh token with invalid JTI" do
      user = UsersFixtures.user_fixture()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:error, error} = UserService.create_refresh_token(%{
        jti: "invalid-jti",
        user_id: user.id,
        expires_at: expires_at
      })
      assert error.type == :validation_error
    end

    test "fails to create refresh token with past expiration" do
      user = UsersFixtures.user_fixture()
      jti = Ecto.UUID.generate()
      past_expires_at = DateTime.utc_now() |> DateTime.add(-3600, :second)

      {:error, error} = UserService.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: past_expires_at
      })
      assert error.type == :validation_error
    end

    test "fails to create refresh token with nil data" do
      {:error, error} = UserService.create_refresh_token(nil)
      assert error.type == :validation_error
    end
  end

  describe "get_refresh_token/1" do
    test "successfully retrieves refresh token by jti" do
      user = UsersFixtures.user_fixture()
      jti = Ecto.UUID.generate()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, created_token} = UserService.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: expires_at
      })

      {:ok, retrieved_token} = UserService.get_refresh_token(jti)
      assert retrieved_token.id == created_token.id
      assert retrieved_token.jti == jti
    end

    test "fails to retrieve non-existent refresh token" do
      fake_jti = Ecto.UUID.generate()

      {:error, error} = UserService.get_refresh_token(fake_jti)
      assert error.type == :not_found
      assert error.reason == :token_not_found
    end

    test "fails to retrieve refresh token with invalid JTI" do
      {:error, error} = UserService.get_refresh_token("invalid-jti")
      assert error.type == :validation_error
    end

    test "fails to retrieve refresh token with nil JTI" do
      {:error, error} = UserService.get_refresh_token(nil)
      assert error.type == :validation_error
    end

    test "fails to retrieve refresh token with empty JTI" do
      {:error, error} = UserService.get_refresh_token("")
      assert error.type == :validation_error
    end
  end

  describe "revoke_refresh_token/1" do
    test "successfully revokes a refresh token" do
      user = UsersFixtures.user_fixture()
      jti = Ecto.UUID.generate()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, _created_token} = UserService.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: expires_at
      })

      {:ok, revoked_token} = UserService.revoke_refresh_token(jti)
      assert LedgerBankApi.Accounts.Schemas.RefreshToken.revoked?(revoked_token) == true
    end

    test "fails to revoke non-existent refresh token" do
      fake_jti = Ecto.UUID.generate()

      {:error, error} = UserService.revoke_refresh_token(fake_jti)
      assert error.type == :not_found
      assert error.reason == :token_not_found
    end

    test "fails to revoke refresh token with invalid JTI" do
      {:error, error} = UserService.revoke_refresh_token("invalid-jti")
      assert error.type == :validation_error
    end

    test "fails to revoke refresh token with nil JTI" do
      {:error, error} = UserService.revoke_refresh_token(nil)
      assert error.type == :validation_error
    end

    test "fails to revoke refresh token with empty JTI" do
      {:error, error} = UserService.revoke_refresh_token("")
      assert error.type == :validation_error
    end

    test "fails to revoke already revoked refresh token" do
      user = UsersFixtures.user_fixture()
      jti = Ecto.UUID.generate()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, _created_token} = UserService.create_refresh_token(%{
        jti: jti,
        user_id: user.id,
        expires_at: expires_at
      })

      # Revoke the token first
      {:ok, _revoked_token} = UserService.revoke_refresh_token(jti)

      # Try to revoke again
      {:error, error} = UserService.revoke_refresh_token(jti)
      assert error.type == :not_found
      assert error.reason == :token_not_found
    end
  end

  describe "revoke_all_refresh_tokens/1" do
    test "successfully revokes all refresh tokens for a user" do
      user = UsersFixtures.user_fixture()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      # Create multiple refresh tokens
      {:ok, _token1} = UserService.create_refresh_token(%{
        jti: Ecto.UUID.generate(),
        user_id: user.id,
        expires_at: expires_at
      })

      {:ok, _token2} = UserService.create_refresh_token(%{
        jti: Ecto.UUID.generate(),
        user_id: user.id,
        expires_at: expires_at
      })

      {:ok, count} = UserService.revoke_all_refresh_tokens(user.id)
      assert count == 2
    end

    test "returns 0 when user has no refresh tokens" do
      user = UsersFixtures.user_fixture()

      {:ok, count} = UserService.revoke_all_refresh_tokens(user.id)
      assert count == 0
    end

    test "handles non-existent user gracefully" do
      fake_user_id = Ecto.UUID.generate()

      {:ok, count} = UserService.revoke_all_refresh_tokens(fake_user_id)
      assert count == 0
    end

    test "fails with invalid user_id" do
      {:error, error} = UserService.revoke_all_refresh_tokens("invalid-uuid")
      assert error.type == :validation_error
    end

    test "fails with nil user_id" do
      {:error, error} = UserService.revoke_all_refresh_tokens(nil)
      assert error.type == :validation_error
    end

    test "fails with empty user_id" do
      {:error, error} = UserService.revoke_all_refresh_tokens("")
      assert error.type == :validation_error
    end

    test "only revokes tokens for the specified user" do
      user1 = UsersFixtures.user_fixture()
      user2 = UsersFixtures.user_fixture()
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

      # Create tokens for both users
      {:ok, token1} = UserService.create_refresh_token(%{
        jti: Ecto.UUID.generate(),
        user_id: user1.id,
        expires_at: expires_at
      })

      {:ok, token2} = UserService.create_refresh_token(%{
        jti: Ecto.UUID.generate(),
        user_id: user2.id,
        expires_at: expires_at
      })

      # Revoke tokens for user1 only
      {:ok, count} = UserService.revoke_all_refresh_tokens(user1.id)
      assert count == 1

      # Verify user1's token is revoked (should still be found but marked as revoked)
      {:ok, revoked_token1} = UserService.get_refresh_token(token1.jti)
      assert LedgerBankApi.Accounts.Schemas.RefreshToken.revoked?(revoked_token1) == true

      # Verify user2's token is still valid
      {:ok, _retrieved_token2} = UserService.get_refresh_token(token2.jti)
    end
  end
end

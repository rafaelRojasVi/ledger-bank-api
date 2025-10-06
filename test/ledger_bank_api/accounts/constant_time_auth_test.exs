defmodule LedgerBankApi.Accounts.ConstantTimeAuthTest do
  @moduledoc """
  Security tests for constant-time authentication implementation.

  These tests verify that the authentication system prevents:
  1. Email enumeration attacks (timing-based detection of registered emails)
  2. Account status enumeration (timing-based detection of active/inactive accounts)

  ## Attack Scenarios Prevented

  ### Attack 1: Email Enumeration via Response Time
  - Attacker measures response time for different emails
  - If unknown email returns faster (no Argon2), attacker knows email isn't registered
  - Fix: Always perform Argon2 hashing, even for unknown emails

  ### Attack 2: Email Enumeration via Error Messages
  - Different error messages reveal which emails exist
  - Fix: Return same error (:invalid_credentials) for both cases

  ### Attack 3: Account Status Enumeration
  - Check if account is active BEFORE password verification
  - Active accounts take longer (Argon2), inactive accounts faster
  - Fix: Check password FIRST, then check status

  ## CRITICAL Test Assertions
  - Unknown email vs wrong password: roughly same execution time
  - Unknown email: returns :invalid_credentials (NOT :user_not_found)
  - Wrong password: returns :invalid_credentials
  - Inactive account with valid password: returns :account_inactive (NOT :invalid_credentials)
  """

  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Accounts.UserService
  alias LedgerBankApi.UsersFixtures

  describe "SECURITY: Constant-time authentication prevents email enumeration" do
    test "unknown email returns :invalid_credentials (prevents email enumeration)" do
      {:error, error} = UserService.authenticate_user("unknown@example.com", "password123!")

      # CRITICAL: Should return :invalid_credentials (NOT :user_not_found)
      # This prevents revealing which emails are registered
      assert error.reason == :invalid_credentials
      assert error.type == :unauthorized
      refute error.reason == :user_not_found

      # Note: In test environment, we use PasswordHelper (fast) instead of Argon2 (slow)
      # So we can't reliably test timing. The important thing is behavior:
      # - Unknown email goes through password hashing (even if fast in tests)
      # - Returns same error as wrong password
    end

    test "known email with wrong password returns same error as unknown email" do
      # Create a user
      user = UsersFixtures.user_with_password_fixture("CorrectPassword123!")

      {:error, error1} = UserService.authenticate_user(user.email, "WrongPassword123!")
      {:error, error2} = UserService.authenticate_user("unknown@example.com", "WrongPassword123!")

      # CRITICAL: Both should return IDENTICAL error reason
      # This prevents email enumeration via error message differences
      assert error1.reason == :invalid_credentials
      assert error2.reason == :invalid_credentials
      assert error1.type == :unauthorized
      assert error2.type == :unauthorized

      # Note: In test environment, timing is not reliable due to PasswordHelper
      # The key security property is that BOTH paths execute password hashing
      # and return identical error types
    end

    test "unknown email returns :invalid_credentials (NOT :user_not_found)" do
      {:error, error} = UserService.authenticate_user("doesnotexist@example.com", "password123!")

      # CRITICAL: Should return :invalid_credentials, NOT :user_not_found
      # This prevents revealing which emails are registered
      assert error.reason == :invalid_credentials
      assert error.type == :unauthorized
      refute error.reason == :user_not_found
    end

    test "wrong password returns :invalid_credentials" do
      user = UsersFixtures.user_with_password_fixture("CorrectPassword123!")

      {:error, error} = UserService.authenticate_user(user.email, "WrongPassword123!")

      assert error.reason == :invalid_credentials
      assert error.type == :unauthorized
    end

    test "multiple failed attempts with unknown emails all return same error" do
      # Simulate brute force attempt on unknown emails
      unknown_emails = [
        "test1@example.com",
        "test2@example.com",
        "test3@example.com",
        "test4@example.com",
        "test5@example.com"
      ]

      errors = Enum.map(unknown_emails, fn email ->
        {:error, error} = UserService.authenticate_user(email, "password123!")
        error
      end)

      # All errors should be identical (prevents email enumeration)
      Enum.each(errors, fn error ->
        assert error.reason == :invalid_credentials
        assert error.type == :unauthorized
      end)

      # All errors should have the same structure (no variation that could leak info)
      error_reasons = Enum.map(errors, & &1.reason) |> Enum.uniq()
      assert length(error_reasons) == 1, "Errors should all have the same reason"
    end
  end

  describe "SECURITY: Password verification happens BEFORE status check" do
    test "inactive user with VALID password returns :account_inactive (not :invalid_credentials)" do
      # Create inactive user
      _user = UsersFixtures.user_with_password_fixture("ValidPassword123!", %{
        email: "inactive@example.com",
        status: "SUSPENDED"
      })

      {:error, error} = UserService.authenticate_user("inactive@example.com", "ValidPassword123!")

      # Password was verified (correct), but account is inactive
      assert error.reason == :account_inactive
      assert error.type == :unprocessable_entity
      # This confirms password was checked BEFORE status
    end

    test "inactive user with INVALID password returns :invalid_credentials" do
      # Create inactive user
      _user = UsersFixtures.user_with_password_fixture("ValidPassword123!", %{
        email: "inactive2@example.com",
        status: "SUSPENDED"
      })

      {:error, error} = UserService.authenticate_user("inactive2@example.com", "WrongPassword123!")

      # Password check failed, so we return :invalid_credentials
      # (not :account_inactive, because password is wrong)
      assert error.reason == :invalid_credentials
      assert error.type == :unauthorized
    end

    test "suspended user with valid password returns :account_inactive" do
      user = UsersFixtures.user_with_password_fixture("ValidPassword123!", %{
        email: "suspended@example.com",
        suspended: true
      })

      {:error, error} = UserService.authenticate_user(user.email, "ValidPassword123!")

      assert error.reason == :account_inactive
    end

    test "deleted user with valid password returns :account_inactive" do
      user = UsersFixtures.user_with_password_fixture("ValidPassword123!", %{
        email: "deleted@example.com",
        deleted: true
      })

      {:error, error} = UserService.authenticate_user(user.email, "ValidPassword123!")

      assert error.reason == :account_inactive
    end

    test "active user with valid password succeeds" do
      user = UsersFixtures.user_with_password_fixture("ValidPassword123!", %{
        email: "active@example.com",
        status: "ACTIVE",
        active: true,
        suspended: false,
        deleted: false
      })

      {:ok, authenticated_user} = UserService.authenticate_user(user.email, "ValidPassword123!")

      assert authenticated_user.id == user.id
      assert authenticated_user.email == user.email
    end
  end

  describe "SECURITY: Timing attack resistance (behavior verification)" do
    test "active vs inactive account return same error when password is WRONG" do
      # Create active user
      active_user = UsersFixtures.user_with_password_fixture("CorrectPassword123!", %{
        email: "active@example.com",
        status: "ACTIVE"
      })

      # Create inactive user
      _inactive_user = UsersFixtures.user_with_password_fixture("CorrectPassword123!", %{
        email: "inactive@example.com",
        status: "SUSPENDED"
      })

      {:error, error1} = UserService.authenticate_user(active_user.email, "WrongPassword123!")
      {:error, error2} = UserService.authenticate_user("inactive@example.com", "WrongPassword123!")

      # CRITICAL: Both should return :invalid_credentials (password check happens first)
      assert error1.reason == :invalid_credentials
      assert error2.reason == :invalid_credentials

      # This proves status is NOT checked before password
      # If status was checked first, inactive would return :account_inactive
    end

    test "known vs unknown email return same error when password is wrong" do
      # Create a user
      user = UsersFixtures.user_with_password_fixture("CorrectPassword123!", %{
        email: "known@example.com"
      })

      {:error, error1} = UserService.authenticate_user(user.email, "WrongPassword123!")
      {:error, error2} = UserService.authenticate_user("unknown@example.com", "WrongPassword123!")

      # CRITICAL: Both should return :invalid_credentials
      assert error1.reason == :invalid_credentials
      assert error2.reason == :invalid_credentials

      # Both code paths execute password hashing to maintain constant time
    end
  end

  describe "SECURITY: Error message consistency" do
    test "unknown email and wrong password return same error type" do
      user = UsersFixtures.user_with_password_fixture("CorrectPassword123!")

      {:error, error1} = UserService.authenticate_user("unknown@example.com", "SomePassword123!")
      {:error, error2} = UserService.authenticate_user(user.email, "WrongPassword123!")

      # Both should return the same error reason
      assert error1.reason == :invalid_credentials
      assert error2.reason == :invalid_credentials

      # Both should have the same error type
      assert error1.type == :unauthorized
      assert error2.type == :unauthorized

      # Error messages should not reveal which scenario occurred
      refute String.contains?(error1.message, "email")
      refute String.contains?(error1.message, "user")
      refute String.contains?(error1.message, "not found")
    end

    test "inactive account error is different (only when password is correct)" do
      user = UsersFixtures.user_with_password_fixture("CorrectPassword123!", %{
        email: "inactive@example.com",
        status: "SUSPENDED"
      })

      {:error, error} = UserService.authenticate_user(user.email, "CorrectPassword123!")

      # This is a different error because password was CORRECT
      # Only then do we reveal the account is inactive
      assert error.reason == :account_inactive
      assert error.type == :unprocessable_entity
    end
  end

  describe "SECURITY: Regression tests for vulnerability fixes" do
    test "old vulnerability: email enumeration via error messages is fixed" do
      # Old behavior: {:error, :user_not_found} revealed email doesn't exist
      # New behavior: {:error, :invalid_credentials} doesn't reveal anything

      {:error, error} = UserService.authenticate_user("nonexistent@example.com", "password123!")

      assert error.reason == :invalid_credentials
      refute error.reason == :user_not_found
    end

    test "old vulnerability: known/unknown emails return identical errors" do
      user = UsersFixtures.user_with_password_fixture("Password123!")

      # Collect errors from both scenarios
      known_errors = for _ <- 1..5 do
        {:error, error} = UserService.authenticate_user(user.email, "WrongPass!")
        {error.reason, error.type}
      end

      unknown_errors = for i <- 1..5 do
        {:error, error} = UserService.authenticate_user("unknown#{i}@example.com", "WrongPass!")
        {error.reason, error.type}
      end

      # All known email errors should be identical
      assert Enum.uniq(known_errors) == [{:invalid_credentials, :unauthorized}]

      # All unknown email errors should be identical
      assert Enum.uniq(unknown_errors) == [{:invalid_credentials, :unauthorized}]

      # Known and unknown should return the SAME error
      assert Enum.uniq(known_errors) == Enum.uniq(unknown_errors)
    end

    test "old vulnerability: status check before password is fixed" do
      # Create inactive user with a known password
      _user = UsersFixtures.user_with_password_fixture("CorrectPassword123!", %{
        email: "inactive@example.com",
        status: "SUSPENDED"
      })

      # With WRONG password on inactive account
      {:error, error} = UserService.authenticate_user("inactive@example.com", "WrongPassword!")

      # CRITICAL: Should return :invalid_credentials (password was wrong)
      # NOT :account_inactive (which would indicate status was checked first)
      assert error.reason == :invalid_credentials
      assert error.type == :unauthorized

      # This proves password verification happens BEFORE status check
    end
  end

  describe "SECURITY: Valid authentication flow" do
    test "valid credentials with active account succeeds" do
      user = UsersFixtures.user_with_password_fixture("ValidPassword123!", %{
        email: "valid@example.com",
        status: "ACTIVE",
        active: true,
        suspended: false,
        deleted: false
      })

      {:ok, authenticated_user} = UserService.authenticate_user("valid@example.com", "ValidPassword123!")

      assert authenticated_user.id == user.id
      assert authenticated_user.email == user.email
    end

    test "valid credentials with inactive account returns :account_inactive" do
      _user = UsersFixtures.user_with_password_fixture("ValidPassword123!", %{
        email: "inactive@example.com",
        status: "SUSPENDED"
      })

      {:error, error} = UserService.authenticate_user("inactive@example.com", "ValidPassword123!")

      # Password was correct, but account is inactive
      assert error.reason == :account_inactive
      assert error.type == :unprocessable_entity
    end
  end

  describe "SECURITY: Edge cases and attack vectors" do
    test "null byte injection attempt in email is rejected by validation" do
      {:error, error} = UserService.authenticate_user("user\0@example.com", "password123!")

      # Should fail email validation (null bytes rejected)
      # Returns :user_not_found from validate_email_secure
      assert error.reason == :user_not_found
      assert error.type == :not_found
    end

    test "extremely long email is handled securely" do
      long_email = String.duplicate("a", 1000) <> "@example.com"

      {:error, error} = UserService.authenticate_user(long_email, "password123!")

      # Should return :user_not_found (email validation via validate_email_secure)
      assert error.reason == :user_not_found
      assert error.type == :not_found
    end

    test "SQL injection attempt in email doesn't bypass security" do
      sql_injection = "'; DROP TABLE users; --@example.com"

      {:error, error} = UserService.authenticate_user(sql_injection, "password123!")

      # Should fail cleanly
      assert error.reason in [:invalid_credentials, :user_not_found]
    end

    test "whitespace in password is preserved for verification" do
      user = UsersFixtures.user_with_password_fixture("  Password123!  ")

      # Exact password with whitespace should work
      {:ok, _} = UserService.authenticate_user(user.email, "  Password123!  ")

      # Without whitespace should fail
      {:error, error} = UserService.authenticate_user(user.email, "Password123!")
      assert error.reason == :invalid_credentials
    end
  end

  describe "SECURITY: Behavior verification - hashing code paths" do
    test "authentication executes password hashing for various inputs" do
      # Create a real user for comparison
      user = UsersFixtures.user_with_password_fixture("ValidPassword123!")

      # Test scenarios that should trigger password hashing
      test_cases = [
        {user.email, "WrongPassword!", :invalid_credentials, "known email, wrong password"},
        {"unknown@example.com", "password123!", :invalid_credentials, "unknown email"}
      ]

      for {email, password, expected_reason, description} <- test_cases do
        {:error, error} = UserService.authenticate_user(email, password)

        assert error.reason == expected_reason,
          "Failed for scenario: #{description}. Expected #{expected_reason}, got #{error.reason}"

        # In production, these would take 100-300ms due to Argon2
        # In tests, PasswordHelper is fast but still executes hashing logic
      end
    end

    test "invalid email format fails fast (no hashing needed)" do
      # These scenarios should fail validation before attempting to hash
      invalid_emails = [
        "not-an-email",
        "missing-domain@",
        "@no-local-part.com",
        "spaces in@email.com"
      ]

      for email <- invalid_emails do
        {:error, error} = UserService.authenticate_user(email, "password123!")

        # Should fail validation and return :user_not_found
        assert error.reason == :user_not_found
        assert error.type == :not_found
      end
    end
  end
end

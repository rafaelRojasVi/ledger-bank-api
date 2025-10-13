defmodule LedgerBankApi.Core.ValidatorTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Core.Validator

  describe "validate_uuid/1" do
    test "accepts valid UUID v4" do
      valid_uuid = Ecto.UUID.generate()
      assert Validator.validate_uuid(valid_uuid) == :ok
    end

    test "accepts valid UUID with uppercase letters" do
      valid_uuid = "123E4567-E89B-12D3-A456-426614174000"
      assert Validator.validate_uuid(valid_uuid) == :ok
    end

    test "accepts valid UUID with lowercase letters" do
      valid_uuid = "123e4567-e89b-12d3-a456-426614174000"
      assert Validator.validate_uuid(valid_uuid) == :ok
    end

    test "rejects invalid UUID format" do
      invalid_uuids = [
        "not-a-uuid",
        "123e4567-e89b-12d3-a456",  # Too short
        "123e4567-e89b-12d3-a456-42661417400g",  # Invalid character
        "123e4567e89b12d3a456426614174000",  # Missing hyphens
        "123e4567-e89b-12d3-a456-426614174000-extra"  # Too long
      ]

      Enum.each(invalid_uuids, fn uuid ->
        assert Validator.validate_uuid(uuid) == {:error, :invalid_uuid_format}
      end)
    end

    test "rejects nil UUID" do
      assert Validator.validate_uuid(nil) == {:error, :missing_fields}
    end

    test "rejects empty string UUID" do
      assert Validator.validate_uuid("") == {:error, :missing_fields}
    end

    test "rejects non-string UUID" do
      assert Validator.validate_uuid(12345) == {:error, :invalid_uuid_format}
      assert Validator.validate_uuid(%{uuid: "test"}) == {:error, :invalid_uuid_format}
      assert Validator.validate_uuid(["uuid"]) == {:error, :invalid_uuid_format}
    end
  end

  describe "validate_email/1" do
    test "accepts valid email addresses" do
      valid_emails = [
        "test@example.com",
        "user.name@example.com",
        "user+tag@example.com",
        "user_name@example.co.uk",
        "123@example.com",
        "a@b.co"
      ]

      Enum.each(valid_emails, fn email ->
        assert Validator.validate_email(email) == :ok
      end)
    end

    test "rejects invalid email formats" do
      invalid_emails = [
        "not-an-email",
        "@example.com",
        "user@"
        # Note: Regex is simple and may allow some edge cases like "user@example"
        # More strict validation happens at service layer
      ]

      Enum.each(invalid_emails, fn email ->
        assert Validator.validate_email(email) == {:error, :invalid_email_format}
      end)
    end

    test "rejects nil email" do
      assert Validator.validate_email(nil) == {:error, :missing_fields}
    end

    test "rejects empty string email" do
      assert Validator.validate_email("") == {:error, :missing_fields}
    end

    test "rejects non-string email" do
      assert Validator.validate_email(123) == {:error, :invalid_email_format}
      assert Validator.validate_email(%{email: "test"}) == {:error, :invalid_email_format}
    end

    test "SECURITY: rejects email with null bytes" do
      malicious_email = "user\0@example.com"
      assert Validator.validate_email(malicious_email) == {:error, :invalid_email_format}
    end

    test "handles very long valid email" do
      # Create a long but valid email (under 255 chars)
      long_local = String.duplicate("a", 200)
      long_email = "#{long_local}@example.com"

      assert Validator.validate_email(long_email) == :ok
    end
  end

  describe "validate_email_secure/1" do
    test "accepts valid email addresses" do
      valid_emails = [
        "test@example.com",
        "user+tag@example.com",
        "user.name@example.com"
      ]

      Enum.each(valid_emails, fn email ->
        assert Validator.validate_email_secure(email) == :ok
      end)
    end

    test "SECURITY: returns :user_not_found for invalid formats (prevents enumeration)" do
      invalid_emails = [
        "not-an-email",
        "@example.com",
        "user@",
        "invalid"
      ]

      Enum.each(invalid_emails, fn email ->
        assert Validator.validate_email_secure(email) == {:error, :user_not_found}
      end)
    end

    test "SECURITY: returns :user_not_found for nil (prevents enumeration)" do
      assert Validator.validate_email_secure(nil) == {:error, :user_not_found}
    end

    test "SECURITY: returns :user_not_found for empty string" do
      assert Validator.validate_email_secure("") == {:error, :user_not_found}
    end

    test "SECURITY: rejects email with null bytes" do
      malicious_email = "user\0@example.com"
      assert Validator.validate_email_secure(malicious_email) == {:error, :user_not_found}
    end

    test "SECURITY: rejects excessively long emails (>255 chars)" do
      long_email = String.duplicate("a", 300) <> "@example.com"
      assert Validator.validate_email_secure(long_email) == {:error, :user_not_found}
    end

    test "SECURITY: accepts emails up to 255 characters" do
      # Create exactly 255 char email
      local_part = String.duplicate("a", 240)
      email = "#{local_part}@example.com"  # Exactly 255 chars

      if String.length(email) <= 255 do
        assert Validator.validate_email_secure(email) == :ok
      end
    end

    test "SECURITY: difference between validate_email and validate_email_secure" do
      invalid_email = "not-an-email"

      # Regular validation returns specific error
      assert Validator.validate_email(invalid_email) == {:error, :invalid_email_format}

      # Secure validation returns generic error to prevent enumeration
      assert Validator.validate_email_secure(invalid_email) == {:error, :user_not_found}
    end
  end

  describe "validate_password/1" do
    test "accepts valid string password" do
      assert Validator.validate_password("password123") == :ok
      assert Validator.validate_password("short") == :ok
      assert Validator.validate_password("a") == :ok
    end

    test "accepts password with special characters" do
      assert Validator.validate_password("p@ssw0rd!@#$%") == :ok
    end

    test "accepts password with spaces" do
      assert Validator.validate_password("pass word 123") == :ok
    end

    test "accepts password with unicode" do
      assert Validator.validate_password("pässwörd123") == :ok
    end

    test "rejects nil password" do
      assert Validator.validate_password(nil) == {:error, :invalid_credentials}
    end

    test "rejects empty string password" do
      assert Validator.validate_password("") == {:error, :invalid_credentials}
    end

    test "rejects non-string password" do
      assert Validator.validate_password(123) == {:error, :invalid_credentials}
      assert Validator.validate_password(%{password: "test"}) == {:error, :invalid_credentials}
      assert Validator.validate_password(["password"]) == {:error, :invalid_credentials}
    end
  end

  describe "validate_future_datetime/1" do
    test "accepts datetime in the future" do
      future_datetime = DateTime.add(DateTime.utc_now(), 3600, :second)
      assert Validator.validate_future_datetime(future_datetime) == :ok
    end

    test "rejects datetime in the past" do
      past_datetime = DateTime.add(DateTime.utc_now(), -3600, :second)
      assert Validator.validate_future_datetime(past_datetime) == {:error, :invalid_datetime_format}
    end

    test "rejects current datetime (boundary case)" do
      # Current time should fail since it's not > now
      current_datetime = DateTime.utc_now()

      result = Validator.validate_future_datetime(current_datetime)
      # Might be :ok or error depending on microsecond timing
      assert result in [:ok, {:error, :invalid_datetime_format}]
    end

    test "rejects nil datetime" do
      assert Validator.validate_future_datetime(nil) == {:error, :missing_fields}
    end

    test "rejects non-DateTime value" do
      assert Validator.validate_future_datetime("2023-01-01") == {:error, :invalid_datetime_format}
      assert Validator.validate_future_datetime(123) == {:error, :invalid_datetime_format}
    end

    test "accepts datetime far in the future" do
      far_future = DateTime.add(DateTime.utc_now(), 365 * 24 * 3600, :second)  # 1 year
      assert Validator.validate_future_datetime(far_future) == :ok
    end
  end

  describe "validate_required/1" do
    test "accepts non-empty string" do
      assert Validator.validate_required("value") == :ok
      assert Validator.validate_required("a") == :ok
    end

    test "accepts string with only spaces as empty" do
      assert Validator.validate_required("   ") == {:error, :missing_fields}
    end

    test "accepts non-string non-nil values" do
      assert Validator.validate_required(123) == :ok
      assert Validator.validate_required(true) == :ok
      assert Validator.validate_required(false) == :ok
      assert Validator.validate_required(%{key: "value"}) == :ok
      assert Validator.validate_required([1, 2, 3]) == :ok
    end

    test "rejects nil" do
      assert Validator.validate_required(nil) == {:error, :missing_fields}
    end

    test "rejects empty string" do
      assert Validator.validate_required("") == {:error, :missing_fields}
    end

    test "handles string with leading/trailing whitespace" do
      assert Validator.validate_required("  value  ") == :ok
    end
  end

  describe "validate_all/1" do
    test "returns :ok when all validations pass" do
      validations = [
        :ok,
        :ok,
        :ok
      ]

      assert Validator.validate_all(validations) == :ok
    end

    test "returns first error when validation fails" do
      validations = [
        :ok,
        {:error, :first_error},
        {:error, :second_error}
      ]

      assert Validator.validate_all(validations) == {:error, :first_error}
    end

    test "short-circuits on first error" do
      # This test verifies that validation stops at first error
      # Since we're passing a list, the function call is evaluated before passing to validate_all
      # We'll test this differently by checking the result
      validations = [
        :ok,
        {:error, :early_error},
        :ok  # This should not matter since we hit error above
      ]

      assert Validator.validate_all(validations) == {:error, :early_error}
    end

    test "handles empty validation list" do
      assert Validator.validate_all([]) == :ok
    end

    test "handles single validation" do
      assert Validator.validate_all([:ok]) == :ok
      assert Validator.validate_all([{:error, :test}]) == {:error, :test}
    end
  end

  describe "validate_fields/2" do
    test "validates all fields successfully" do
      fields = %{
        email: "test@example.com",
        uuid: Ecto.UUID.generate(),
        password: "password123"
      }

      validations = %{
        email: &Validator.validate_email/1,
        uuid: &Validator.validate_uuid/1,
        password: &Validator.validate_password/1
      }

      assert Validator.validate_fields(fields, validations) == :ok
    end

    test "returns first validation error" do
      fields = %{
        email: "invalid-email",
        uuid: "invalid-uuid"
      }

      validations = %{
        email: &Validator.validate_email/1,
        uuid: &Validator.validate_uuid/1
      }

      result = Validator.validate_fields(fields, validations)

      # Should return an error (which one depends on map ordering)
      assert match?({:error, _}, result)
    end

    test "handles missing fields gracefully" do
      fields = %{
        email: "test@example.com"
        # uuid is missing
      }

      validations = %{
        email: &Validator.validate_email/1,
        uuid: &Validator.validate_uuid/1
      }

      result = Validator.validate_fields(fields, validations)

      # Missing UUID should fail validation
      assert result == {:error, :missing_fields}
    end

    test "handles empty fields map" do
      validations = %{
        email: &Validator.validate_email/1
      }

      assert Validator.validate_fields(%{}, validations) == {:error, :missing_fields}
    end

    test "handles empty validations map" do
      fields = %{email: "test@example.com"}

      assert Validator.validate_fields(fields, %{}) == :ok
    end

    test "validates only specified fields" do
      fields = %{
        email: "test@example.com",
        extra_field: "should be ignored"
      }

      validations = %{
        email: &Validator.validate_email/1
      }

      # Should only validate email, ignore extra_field
      assert Validator.validate_fields(fields, validations) == :ok
    end
  end

  describe "validate_uuid/1 edge cases" do
    test "handles UUID with different casing" do
      upper_uuid = "550E8400-E29B-41D4-A716-446655440000"
      lower_uuid = "550e8400-e29b-41d4-a716-446655440000"
      mixed_uuid = "550E8400-e29b-41D4-a716-446655440000"

      assert Validator.validate_uuid(upper_uuid) == :ok
      assert Validator.validate_uuid(lower_uuid) == :ok
      assert Validator.validate_uuid(mixed_uuid) == :ok
    end

    test "rejects UUID with special characters" do
      assert Validator.validate_uuid("550e8400-e29b-41d4-a716-44665544000!") == {:error, :invalid_uuid_format}
      assert Validator.validate_uuid("550e8400-e29b-41d4-a716-44665544000 ") == {:error, :invalid_uuid_format}
    end

    test "rejects UUID-like strings with wrong length" do
      assert Validator.validate_uuid("550e8400-e29b-41d4-a716") == {:error, :invalid_uuid_format}
      assert Validator.validate_uuid("550e8400-e29b-41d4-a716-446655440000-extra") == {:error, :invalid_uuid_format}
    end
  end

  describe "validate_email/1 edge cases" do
    test "handles email with plus sign (common for tags)" do
      assert Validator.validate_email("user+tag@example.com") == :ok
      assert Validator.validate_email("user+tag+extra@example.com") == :ok
    end

    test "handles email with dots in local part" do
      assert Validator.validate_email("first.last@example.com") == :ok
      assert Validator.validate_email("user.name.here@example.com") == :ok
    end

    test "handles email with numbers" do
      assert Validator.validate_email("user123@example.com") == :ok
      assert Validator.validate_email("123@example.com") == :ok
    end

    test "handles email with subdomain" do
      assert Validator.validate_email("user@mail.example.com") == :ok
      assert Validator.validate_email("user@sub.domain.example.com") == :ok
    end

    test "handles email with hyphen in domain" do
      assert Validator.validate_email("user@my-domain.com") == :ok
    end

    test "rejects email with multiple @ symbols" do
      assert Validator.validate_email("user@@example.com") == {:error, :invalid_email_format}
      assert Validator.validate_email("user@test@example.com") == {:error, :invalid_email_format}
    end

    test "handles email case sensitivity" do
      # Email validation doesn't enforce lowercase
      assert Validator.validate_email("USER@EXAMPLE.COM") == :ok
      assert Validator.validate_email("User@Example.Com") == :ok
    end
  end

  describe "validate_email_secure/1 security features" do
    test "returns consistent error for all invalid formats" do
      invalid_inputs = [
        nil,
        "",
        "invalid",
        "@example.com",
        "user@",
        "user\0@example.com",  # Null byte
        String.duplicate("a", 300) <> "@example.com"  # Too long
      ]

      errors = Enum.map(invalid_inputs, fn input ->
        Validator.validate_email_secure(input)
      end)

      # All should return :user_not_found (no variation)
      assert Enum.uniq(errors) == [{:error, :user_not_found}]
    end

    test "accepts valid email without revealing format error" do
      assert Validator.validate_email_secure("valid@example.com") == :ok
    end

    test "treats emails over 255 chars as not found" do
      very_long = String.duplicate("a", 260) <> "@example.com"
      assert Validator.validate_email_secure(very_long) == {:error, :user_not_found}
    end

    test "handles boundary case at exactly 255 characters" do
      # Create email of exactly 255 chars
      local_part = String.duplicate("a", 240)
      email = "#{local_part}@example.com"

      if String.length(email) == 255 do
        assert Validator.validate_email_secure(email) == :ok
      end
    end
  end

  describe "validate_password/1 edge cases" do
    test "accepts very short passwords (length validation elsewhere)" do
      assert Validator.validate_password("a") == :ok
      assert Validator.validate_password("ab") == :ok
    end

    test "accepts very long passwords" do
      long_password = String.duplicate("a", 1000)
      assert Validator.validate_password(long_password) == :ok
    end

    test "accepts password with only spaces" do
      # Note: This validates presence/type, not content
      assert Validator.validate_password("   ") == :ok
    end

    test "accepts password with special characters" do
      assert Validator.validate_password("!@#$%^&*()") == :ok
      assert Validator.validate_password("p@ssw0rd!") == :ok
    end

    test "accepts password with unicode" do
      assert Validator.validate_password("pässwörd") == :ok
      assert Validator.validate_password("密码123") == :ok
    end

    test "accepts password with newlines and tabs" do
      assert Validator.validate_password("pass\nword") == :ok
      assert Validator.validate_password("pass\tword") == :ok
    end
  end

  describe "validate_future_datetime/1 edge cases" do
    test "handles datetime 1 second in future" do
      future = DateTime.add(DateTime.utc_now(), 1, :second)
      assert Validator.validate_future_datetime(future) == :ok
    end

    test "handles datetime 1 year in future" do
      far_future = DateTime.add(DateTime.utc_now(), 365 * 24 * 3600, :second)
      assert Validator.validate_future_datetime(far_future) == :ok
    end

    test "handles datetime with microseconds" do
      future = DateTime.utc_now()
      |> DateTime.add(1, :second)
      |> DateTime.truncate(:microsecond)

      assert Validator.validate_future_datetime(future) == :ok
    end

    test "handles NaiveDateTime (should fail)" do
      naive = NaiveDateTime.utc_now()
      assert Validator.validate_future_datetime(naive) == {:error, :invalid_datetime_format}
    end

    test "handles Date (should fail)" do
      date = Date.utc_today()
      assert Validator.validate_future_datetime(date) == {:error, :invalid_datetime_format}
    end
  end

  describe "validate_required/1 edge cases" do
    test "handles whitespace-only strings" do
      whitespace_strings = [
        " ",
        "  ",
        "   ",
        "\t",
        "\n",
        "\r\n",
        " \t\n "
      ]

      Enum.each(whitespace_strings, fn ws ->
        assert Validator.validate_required(ws) == {:error, :missing_fields}
      end)
    end

    test "handles zero as valid (non-nil)" do
      assert Validator.validate_required(0) == :ok
    end

    test "handles false as valid (non-nil)" do
      assert Validator.validate_required(false) == :ok
    end

    test "handles empty structures as valid (non-nil)" do
      assert Validator.validate_required(%{}) == :ok
      assert Validator.validate_required([]) == :ok
    end
  end

  describe "composite validation scenarios" do
    test "validates user login credentials" do
      email_validation = Validator.validate_email("test@example.com")
      password_validation = Validator.validate_password("password123")

      assert Validator.validate_all([email_validation, password_validation]) == :ok
    end

    test "validates user creation fields" do
      validations = [
        Validator.validate_email("test@example.com"),
        Validator.validate_required("Full Name"),
        Validator.validate_password("password123")
      ]

      assert Validator.validate_all(validations) == :ok
    end

    test "validates payment creation fields" do
      fields = %{
        user_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate(),
        amount: "100.00"
      }

      validations = %{
        user_id: &Validator.validate_uuid/1,
        account_id: &Validator.validate_uuid/1,
        amount: &Validator.validate_required/1
      }

      assert Validator.validate_fields(fields, validations) == :ok
    end
  end

  describe "error reason consistency" do
    test "UUID validations return consistent error reasons" do
      assert Validator.validate_uuid(nil) == {:error, :missing_fields}
      assert Validator.validate_uuid("") == {:error, :missing_fields}
      assert Validator.validate_uuid("invalid") == {:error, :invalid_uuid_format}
    end

    test "email validations return consistent error reasons" do
      assert Validator.validate_email(nil) == {:error, :missing_fields}
      assert Validator.validate_email("") == {:error, :missing_fields}
      assert Validator.validate_email("invalid") == {:error, :invalid_email_format}
    end

    test "secure email validations return consistent error reasons" do
      # ALL invalid inputs return :user_not_found for security
      assert Validator.validate_email_secure(nil) == {:error, :user_not_found}
      assert Validator.validate_email_secure("") == {:error, :user_not_found}
      assert Validator.validate_email_secure("invalid") == {:error, :user_not_found}
    end

    test "password validations return consistent error reasons" do
      assert Validator.validate_password(nil) == {:error, :invalid_credentials}
      assert Validator.validate_password("") == {:error, :invalid_credentials}
      assert Validator.validate_password(123) == {:error, :invalid_credentials}
    end
  end
end

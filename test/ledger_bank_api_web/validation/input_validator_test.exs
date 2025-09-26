defmodule LedgerBankApiWeb.Validation.InputValidatorTest do
  use LedgerBankApi.DataCase, async: true

  alias LedgerBankApiWeb.Validation.InputValidator
  alias LedgerBankApi.Core.Error

  # ============================================================================
  # USER CREATION VALIDATION TESTS
  # ============================================================================

  describe "validate_user_creation/1" do
    test "successfully validates user creation with valid attributes" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:ok, validated_params} = InputValidator.validate_user_creation(params)
      assert validated_params.email == "test@example.com"
      assert validated_params.full_name == "John Doe"
      assert validated_params.role == "user"
      assert validated_params.password == "ValidPassword123!"
      assert validated_params.password_confirmation == "ValidPassword123!"
    end

    test "successfully validates admin user creation with longer password" do
      params = %{
        "email" => "admin@example.com",
        "full_name" => "Admin User",
        "role" => "admin",
        "password" => "AdminPassword123!",
        "password_confirmation" => "AdminPassword123!"
      }

      assert {:ok, validated_params} = InputValidator.validate_user_creation(params)
      assert validated_params.role == "admin"
    end

    test "successfully validates support user creation with longer password" do
      params = %{
        "email" => "support@example.com",
        "full_name" => "Support User",
        "role" => "support",
        "password" => "SupportPassword123!",
        "password_confirmation" => "SupportPassword123!"
      }

      assert {:ok, validated_params} = InputValidator.validate_user_creation(params)
      assert validated_params.role == "support"
    end

    test "fails to validate user creation with missing email" do
      params = %{
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with nil email" do
      params = %{
        "email" => nil,
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with empty email" do
      params = %{
        "email" => "",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with invalid email format" do
      params = %{
        "email" => "invalid-email",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_email_format}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with missing full_name" do
      params = %{
        "email" => "test@example.com",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with nil full_name" do
      params = %{
        "email" => "test@example.com",
        "full_name" => nil,
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with empty full_name" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with full_name exceeding 255 characters" do
      long_name = String.duplicate("A", 256)
      params = %{
        "email" => "test@example.com",
        "full_name" => long_name,
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_name_format}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with missing role" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_role}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with invalid role" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "invalid_role",
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_role}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with nil role" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => nil,
        "password" => "ValidPassword123!",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_role}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with missing password" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with nil password" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => nil,
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with empty password" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "",
        "password_confirmation" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with password too short for admin role" do
      params = %{
        "email" => "admin@example.com",
        "full_name" => "Admin User",
        "role" => "admin",
        "password" => "Short123!",
        "password_confirmation" => "Short123!"
      }

      assert {:error, %Error{reason: :invalid_password_format}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with password too short for support role" do
      params = %{
        "email" => "support@example.com",
        "full_name" => "Support User",
        "role" => "support",
        "password" => "Short123!",
        "password_confirmation" => "Short123!"
      }

      assert {:error, %Error{reason: :invalid_password_format}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with missing password_confirmation" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with nil password_confirmation" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => nil
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with empty password_confirmation" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => ""
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with password mismatch" do
      params = %{
        "email" => "test@example.com",
        "full_name" => "John Doe",
        "role" => "user",
        "password" => "ValidPassword123!",
        "password_confirmation" => "DifferentPassword123!"
      }

      assert {:error, %Error{reason: :invalid_password_format}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with all missing fields" do
      params = %{}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(params)
    end

    test "fails to validate user creation with nil params" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_creation(nil)
    end
  end

  # ============================================================================
  # USER UPDATE VALIDATION TESTS
  # ============================================================================

  describe "validate_user_update/1" do
    test "successfully validates user update with valid email" do
      params = %{"email" => "newemail@example.com"}

      assert {:ok, validated_params} = InputValidator.validate_user_update(params)
      assert validated_params.email == "newemail@example.com"
    end

    test "successfully validates user update with valid full_name" do
      params = %{"full_name" => "New Name"}

      assert {:ok, validated_params} = InputValidator.validate_user_update(params)
      assert validated_params.full_name == "New Name"
    end

    test "successfully validates user update with valid role" do
      params = %{"role" => "admin"}

      assert {:ok, validated_params} = InputValidator.validate_user_update(params)
      assert validated_params.role == "admin"
    end

    test "successfully validates user update with valid status" do
      params = %{"status" => "SUSPENDED"}

      assert {:ok, validated_params} = InputValidator.validate_user_update(params)
      assert validated_params.status == "SUSPENDED"
    end

    test "successfully validates user update with multiple valid fields" do
      params = %{
        "email" => "newemail@example.com",
        "full_name" => "New Name",
        "role" => "support"
      }

      assert {:ok, validated_params} = InputValidator.validate_user_update(params)
      assert validated_params.email == "newemail@example.com"
      assert validated_params.full_name == "New Name"
      assert validated_params.role == "support"
    end

    test "fails to validate user update with no fields provided" do
      params = %{}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_update(params)
    end

    test "fails to validate user update with nil params" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_update(nil)
    end

    test "fails to validate user update with all nil fields" do
      params = %{
        "email" => nil,
        "full_name" => nil,
        "role" => nil,
        "status" => nil
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_update(params)
    end

    test "fails to validate user update with invalid email format" do
      params = %{"email" => "invalid-email"}

      assert {:error, %Error{reason: :invalid_email_format}} = InputValidator.validate_user_update(params)
    end

    test "fails to validate user update with empty email" do
      params = %{"email" => ""}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_update(params)
    end

    test "fails to validate user update with full_name exceeding 255 characters" do
      long_name = String.duplicate("A", 256)
      params = %{"full_name" => long_name}

      assert {:error, %Error{reason: :invalid_name_format}} = InputValidator.validate_user_update(params)
    end

    test "fails to validate user update with empty full_name" do
      params = %{"full_name" => ""}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_update(params)
    end

    test "fails to validate user update with invalid role" do
      params = %{"role" => "invalid_role"}

      assert {:error, %Error{reason: :invalid_role}} = InputValidator.validate_user_update(params)
    end

    test "fails to validate user update with invalid status" do
      params = %{"status" => "INVALID"}

      assert {:error, %Error{reason: :invalid_status}} = InputValidator.validate_user_update(params)
    end

    test "successfully validates user update with valid fields and ignores invalid ones" do
      params = %{
        "email" => "valid@example.com",
        "invalid_field" => "should_be_ignored",
        "role" => "admin"
      }

      assert {:ok, validated_params} = InputValidator.validate_user_update(params)
      assert validated_params.email == "valid@example.com"
      assert validated_params.role == "admin"
      refute Map.has_key?(validated_params, :invalid_field)
    end
  end

  # ============================================================================
  # PASSWORD CHANGE VALIDATION TESTS
  # ============================================================================

  describe "validate_password_change/2" do
    test "successfully validates password change with valid attributes" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "new_password" => "NewPassword123!",
        "password_confirmation" => "NewPassword123!"
      }

      assert {:ok, validated_params} = InputValidator.validate_password_change(params)
      assert validated_params.current_password == "CurrentPassword123!"
      assert validated_params.password == "NewPassword123!"
      assert validated_params.password_confirmation == "NewPassword123!"
    end

    test "successfully validates password change for admin with longer password" do
      params = %{
        "current_password" => "CurrentAdminPassword123!",
        "new_password" => "NewAdminPassword123!",
        "password_confirmation" => "NewAdminPassword123!"
      }

      assert {:ok, validated_params} = InputValidator.validate_password_change(params, "admin")
      assert validated_params.password == "NewAdminPassword123!"
    end

    test "successfully validates password change for support with longer password" do
      params = %{
        "current_password" => "CurrentSupportPassword123!",
        "new_password" => "NewSupportPassword123!",
        "password_confirmation" => "NewSupportPassword123!"
      }

      assert {:ok, validated_params} = InputValidator.validate_password_change(params, "support")
      assert validated_params.password == "NewSupportPassword123!"
    end

    test "fails to validate password change with missing current_password" do
      params = %{
        "new_password" => "NewPassword123!",
        "password_confirmation" => "NewPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with nil current_password" do
      params = %{
        "current_password" => nil,
        "new_password" => "NewPassword123!",
        "password_confirmation" => "NewPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with empty current_password" do
      params = %{
        "current_password" => "",
        "new_password" => "NewPassword123!",
        "password_confirmation" => "NewPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with missing new_password" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "password_confirmation" => "NewPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with nil new_password" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "new_password" => nil,
        "password_confirmation" => "NewPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with empty new_password" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "new_password" => "",
        "password_confirmation" => "NewPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with new password too short for admin" do
      params = %{
        "current_password" => "CurrentAdminPassword123!",
        "new_password" => "Short123!",
        "password_confirmation" => "Short123!"
      }

      assert {:error, %Error{reason: :invalid_password_format}} = InputValidator.validate_password_change(params, "admin")
    end

    test "fails to validate password change with new password too short for support" do
      params = %{
        "current_password" => "CurrentSupportPassword123!",
        "new_password" => "Short123!",
        "password_confirmation" => "Short123!"
      }

      assert {:error, %Error{reason: :invalid_password_format}} = InputValidator.validate_password_change(params, "support")
    end

    test "fails to validate password change with missing password_confirmation" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "new_password" => "NewPassword123!"
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with nil password_confirmation" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "new_password" => "NewPassword123!",
        "password_confirmation" => nil
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with empty password_confirmation" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "new_password" => "NewPassword123!",
        "password_confirmation" => ""
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with password mismatch" do
      params = %{
        "current_password" => "CurrentPassword123!",
        "new_password" => "NewPassword123!",
        "password_confirmation" => "DifferentPassword123!"
      }

      assert {:error, %Error{reason: :invalid_password_format}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with all missing fields" do
      params = %{}

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(params)
    end

    test "fails to validate password change with nil params" do
      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_password_change(nil)
    end
  end

  # ============================================================================
  # LOGIN VALIDATION TESTS
  # ============================================================================

  describe "validate_login/1" do
    test "successfully validates login with valid credentials" do
      params = %{
        "email" => "test@example.com",
        "password" => "ValidPassword123!"
      }

      assert {:ok, validated_params} = InputValidator.validate_login(params)
      assert validated_params.email == "test@example.com"
      assert validated_params.password == "ValidPassword123!"
    end

    test "fails to validate login with missing email" do
      params = %{"password" => "ValidPassword123!"}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with nil email" do
      params = %{
        "email" => nil,
        "password" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with empty email" do
      params = %{
        "email" => "",
        "password" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with invalid email format" do
      params = %{
        "email" => "invalid-email",
        "password" => "ValidPassword123!"
      }

      assert {:error, %Error{reason: :invalid_email_format}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with missing password" do
      params = %{"email" => "test@example.com"}

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with nil password" do
      params = %{
        "email" => "test@example.com",
        "password" => nil
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with empty password" do
      params = %{
        "email" => "test@example.com",
        "password" => ""
      }

      assert {:error, %Error{reason: :invalid_credentials}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with all missing fields" do
      params = %{}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_login(params)
    end

    test "fails to validate login with nil params" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_login(nil)
    end
  end

  # ============================================================================
  # REFRESH TOKEN VALIDATION TESTS
  # ============================================================================

  describe "validate_refresh_token/1" do
    test "successfully validates refresh token with valid token" do
      params = %{"refresh_token" => "valid-refresh-token-123"}

      assert {:ok, validated_params} = InputValidator.validate_refresh_token(params)
      assert validated_params.refresh_token == "valid-refresh-token-123"
    end

    test "fails to validate refresh token with missing token" do
      params = %{}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_refresh_token(params)
    end

    test "fails to validate refresh token with nil token" do
      params = %{"refresh_token" => nil}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_refresh_token(params)
    end

    test "fails to validate refresh token with empty token" do
      params = %{"refresh_token" => ""}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_refresh_token(params)
    end

    test "fails to validate refresh token with non-string token" do
      params = %{"refresh_token" => 123}

      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_refresh_token(params)
    end

    test "fails to validate refresh token with nil params" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_refresh_token(nil)
    end
  end

  # ============================================================================
  # ACCESS TOKEN VALIDATION TESTS
  # ============================================================================

  describe "validate_access_token/1" do
    test "successfully validates access token with valid token" do
      token = "valid-access-token-123"

      assert {:ok, validated_token} = InputValidator.validate_access_token(token)
      assert validated_token == token
    end

    test "fails to validate access token with empty token" do
      assert {:error, %Error{reason: :invalid_token}} = InputValidator.validate_access_token("")
    end

    test "fails to validate access token with nil token" do
      assert {:error, %Error{reason: :invalid_token}} = InputValidator.validate_access_token(nil)
    end

    test "fails to validate access token with non-string token" do
      assert {:error, %Error{reason: :invalid_token}} = InputValidator.validate_access_token(123)
    end
  end

  # ============================================================================
  # USER ID VALIDATION TESTS
  # ============================================================================

  describe "validate_user_id/1" do
    test "successfully validates user ID with valid UUID" do
      user_id = "550e8400-e29b-41d4-a716-446655440000"

      assert {:ok, validated_id} = InputValidator.validate_user_id(user_id)
      assert validated_id == user_id
    end

    test "fails to validate user ID with invalid UUID format" do
      assert {:error, %Error{reason: :invalid_uuid_format}} = InputValidator.validate_user_id("invalid-uuid")
    end

    test "fails to validate user ID with nil" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_id(nil)
    end

    test "fails to validate user ID with empty string" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_user_id("")
    end

    test "fails to validate user ID with non-string" do
      assert {:error, %Error{reason: :invalid_uuid_format}} = InputValidator.validate_user_id(123)
    end
  end

  # ============================================================================
  # UUID VALIDATION TESTS
  # ============================================================================

  describe "validate_uuid/2" do
    test "successfully validates UUID with valid UUID" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      assert {:ok, validated_uuid} = InputValidator.validate_uuid(uuid)
      assert validated_uuid == uuid
    end

    test "successfully validates UUID with custom context" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      context = %{source: "custom_context"}

      assert {:ok, validated_uuid} = InputValidator.validate_uuid(uuid, context)
      assert validated_uuid == uuid
    end

    test "fails to validate UUID with invalid format" do
      assert {:error, %Error{reason: :invalid_uuid_format}} = InputValidator.validate_uuid("invalid-uuid")
    end

    test "fails to validate UUID with nil" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_uuid(nil)
    end

    test "fails to validate UUID with empty string" do
      assert {:error, %Error{reason: :missing_fields}} = InputValidator.validate_uuid("")
    end

    test "fails to validate UUID with non-string" do
      assert {:error, %Error{reason: :invalid_uuid_format}} = InputValidator.validate_uuid(123)
    end
  end

  # ============================================================================
  # PAGINATION PARAMETER EXTRACTION TESTS
  # ============================================================================

  describe "extract_pagination_params/2" do
    test "successfully extracts pagination params with valid values" do
      params = %{"page" => "2", "page_size" => "10"}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 2
      assert pagination_params.page_size == 10
    end

    test "successfully extracts pagination params with default values" do
      params = %{}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 1
      assert pagination_params.page_size == 20
    end

    test "successfully extracts pagination params with nil values" do
      params = %{"page" => nil, "page_size" => nil}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 1
      assert pagination_params.page_size == 20
    end

    test "successfully extracts pagination params with empty values" do
      params = %{"page" => "", "page_size" => ""}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 1
      assert pagination_params.page_size == 20
    end

    test "successfully extracts pagination params with invalid values" do
      params = %{"page" => "invalid", "page_size" => "invalid"}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 1
      assert pagination_params.page_size == 20
    end

    test "successfully extracts pagination params with page_size exceeding maximum" do
      params = %{"page" => "1", "page_size" => "150"}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 1
      assert pagination_params.page_size == 100
    end

    test "successfully extracts pagination params with page less than 1" do
      params = %{"page" => "0", "page_size" => "10"}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 1
      assert pagination_params.page_size == 10
    end

    test "successfully extracts pagination params with page_size less than 1" do
      params = %{"page" => "1", "page_size" => "0"}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params)
      assert pagination_params.page == 1
      assert pagination_params.page_size == 20
    end

    test "successfully extracts pagination params with custom context" do
      params = %{"page" => "3", "page_size" => "15"}
      context = %{source: "custom_context"}

      assert {:ok, pagination_params} = InputValidator.extract_pagination_params(params, context)
      assert pagination_params.page == 3
      assert pagination_params.page_size == 15
    end
  end

  # ============================================================================
  # SORT PARAMETER EXTRACTION TESTS
  # ============================================================================

  describe "extract_sort_params/2" do
    test "successfully extracts sort params with single field" do
      params = %{"sort" => "name"}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == [{:name, :asc}]
    end

    test "successfully extracts sort params with single field and direction" do
      params = %{"sort" => "name:desc"}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == [{:name, :desc}]
    end

    test "successfully extracts sort params with multiple fields" do
      params = %{"sort" => "name:asc,email:desc,created_at:asc"}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == [{:name, :asc}, {:email, :desc}, {:created_at, :asc}]
    end

    test "successfully extracts sort params with mixed fields" do
      params = %{"sort" => "name,email:desc,created_at"}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == [{:name, :asc}, {:email, :desc}, {:created_at, :asc}]
    end

    test "successfully extracts sort params with no sort parameter" do
      params = %{}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == []
    end

    test "successfully extracts sort params with nil sort parameter" do
      params = %{"sort" => nil}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == []
    end

    test "successfully extracts sort params with empty sort parameter" do
      params = %{"sort" => ""}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      # Empty string gets parsed as an empty field name with asc direction
      assert sort_params == [{:"", :asc}]
    end

    test "successfully extracts sort params with invalid sort parameter" do
      params = %{"sort" => "invalid:invalid"}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == []
    end

    test "successfully extracts sort params with non-string sort parameter" do
      params = %{"sort" => 123}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params)
      assert sort_params == []
    end

    test "successfully extracts sort params with custom context" do
      params = %{"sort" => "name:desc"}
      context = %{source: "custom_context"}

      assert {:ok, sort_params} = InputValidator.extract_sort_params(params, context)
      assert sort_params == [{:name, :desc}]
    end
  end

  # ============================================================================
  # FILTER PARAMETER EXTRACTION TESTS
  # ============================================================================

  describe "extract_filter_params/2" do
    test "successfully extracts filter params with valid filters" do
      params = %{
        "status" => "ACTIVE",
        "role" => "user",
        "active" => "true",
        "page" => "1",
        "page_size" => "20",
        "sort" => "name:asc"
      }

      assert {:ok, filter_params} = InputValidator.extract_filter_params(params)
      assert filter_params.status == "ACTIVE"
      assert filter_params.role == "user"
      assert filter_params.active == "true"
      refute Map.has_key?(filter_params, :page)
      refute Map.has_key?(filter_params, :page_size)
      refute Map.has_key?(filter_params, :sort)
    end

    test "successfully extracts filter params with no filters" do
      params = %{"page" => "1", "page_size" => "20"}

      assert {:ok, filter_params} = InputValidator.extract_filter_params(params)
      assert map_size(filter_params) == 0
    end

    test "successfully extracts filter params with empty filters" do
      params = %{}

      assert {:ok, filter_params} = InputValidator.extract_filter_params(params)
      assert map_size(filter_params) == 0
    end

    test "successfully extracts filter params with nil values" do
      params = %{
        "status" => nil,
        "role" => "user",
        "active" => nil
      }

      assert {:ok, filter_params} = InputValidator.extract_filter_params(params)
      assert filter_params.role == "user"
      refute Map.has_key?(filter_params, :status)
      refute Map.has_key?(filter_params, :active)
    end

    test "successfully extracts filter params with empty string values" do
      params = %{
        "status" => "",
        "role" => "user",
        "active" => ""
      }

      assert {:ok, filter_params} = InputValidator.extract_filter_params(params)
      assert filter_params.role == "user"
      refute Map.has_key?(filter_params, :status)
      refute Map.has_key?(filter_params, :active)
    end

    test "successfully extracts filter params with non-string values" do
      params = %{
        "status" => 123,
        "role" => "user",
        "active" => true
      }

      assert {:ok, filter_params} = InputValidator.extract_filter_params(params)
      assert filter_params.role == "user"
      refute Map.has_key?(filter_params, :status)
      refute Map.has_key?(filter_params, :active)
    end

    test "successfully extracts filter params with custom context" do
      params = %{"status" => "ACTIVE", "role" => "user"}
      context = %{source: "custom_context"}

      assert {:ok, filter_params} = InputValidator.extract_filter_params(params, context)
      assert filter_params.status == "ACTIVE"
      assert filter_params.role == "user"
    end
  end
end

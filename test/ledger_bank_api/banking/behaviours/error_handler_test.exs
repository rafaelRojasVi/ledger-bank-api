defmodule LedgerBankApi.Banking.Behaviours.ErrorHandlerTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  alias Ecto.Changeset

  describe "with_error_handling/2" do
    test "handles successful operations" do
      context = %{action: :test_action, user_id: "user_123"}

      result = ErrorHandler.with_error_handling(fn ->
        {:ok, "successful result"}
      end, context)

      assert {:ok, "successful result"} = result
    end

    test "handles successful operations returning data directly" do
      context = %{action: :test_action, user_id: "user_123"}

      result = ErrorHandler.with_error_handling(fn ->
        "direct result"
      end, context)

      assert {:ok, "direct result"} = result
    end

    test "handles paginated responses correctly" do
      context = %{action: :list_payments, user_id: "user_123"}
      paginated_data = %{
        data: [%{id: 1, amount: 100}],
        pagination: %{page: 1, page_size: 10, total_count: 1}
      }

      result = ErrorHandler.with_error_handling(fn ->
        {:ok, paginated_data}
      end, context)

      assert {:ok, ^paginated_data} = result
    end

    test "handles Ecto changeset errors" do
      context = %{action: :create_user, user_id: "user_123"}

      changeset = %Changeset{
        valid?: false,
        errors: [email: {"has invalid format", [validation: :format]}],
        data: %{},
        changes: %{email: "invalid-email"}
      }

      result = ErrorHandler.with_error_handling(fn ->
        {:error, changeset}
      end, context)

      assert {:error, %{error: error}} = result
      assert error.type == :validation_error
      assert error.code == 400
      assert error.message == "Validation failed"
      assert is_map(error.details.errors)
    end

    test "handles Ecto constraint errors" do
      context = %{action: :create_user, user_id: "user_123"}

      constraint_error = %Ecto.ConstraintError{
        type: :unique,
        constraint: "users_email_index",
        message: "unique constraint violated"
      }

      result = ErrorHandler.with_error_handling(fn ->
        {:error, constraint_error}
      end, context)

      assert {:error, %{error: error}} = result
      assert error.type == :conflict
      assert error.code == 409
      assert String.contains?(error.message, "Constraint violation")
    end

    test "handles business logic errors with proper structure" do
      context = %{action: :create_payment, user_id: "user_123"}

      business_error = %{type: :insufficient_funds, message: "Not enough money"}

      result = ErrorHandler.with_error_handling(fn ->
        {:error, business_error}
      end, context)

      assert {:error, %{error: error}} = result
      assert error.type == :insufficient_funds
      assert error.code == 422
      assert error.message == "Not enough money"
    end

    test "handles atom errors using hybrid approach" do
      context = %{action: :get_user, user_id: "user_123"}

      result = ErrorHandler.with_error_handling(fn ->
        {:error, :not_found}
      end, context)

      assert {:error, %{error: error}} = result
      assert error.type == :not_found
      assert error.code == 404
      assert error.details.reason == :not_found
      assert error.message == "Resource not found"
    end

    test "handles string errors" do
      context = %{action: :process_payment, user_id: "user_123"}

      result = ErrorHandler.with_error_handling(fn ->
        {:error, "Validation error: Invalid amount"}
      end, context)

      assert {:error, %{error: error}} = result
      assert error.type == :validation_error
      assert error.code == 400
      assert error.message == "Validation error: Invalid amount"
    end

    test "handles runtime errors" do
      context = %{action: :complex_operation, user_id: "user_123"}

      result = ErrorHandler.with_error_handling(fn ->
        raise RuntimeError, "Something went wrong"
      end, context)

      assert {:error, %{error: error}} = result
      assert error.type == :internal_server_error
      assert error.code == 500
      assert String.contains?(error.message, "unexpected error")
    end

    test "handles already formatted error responses" do
      context = %{action: :test_action, user_id: "user_123"}
      formatted_error = %{
        error: %{
          type: :validation_error,
          message: "Already formatted",
          code: 400,
          details: %{}
        }
      }

      result = ErrorHandler.with_error_handling(fn ->
        formatted_error
      end, context)

      assert {:error, ^formatted_error} = result
    end

    test "preserves context in error details" do
      context = %{action: :process_payment, payment_id: "pay_123", user_id: "user_456"}

      result = ErrorHandler.with_error_handling(fn ->
        {:error, :insufficient_funds}
      end, context)

      assert {:error, %{error: error}} = result
      assert error.details.context == context
    end
  end

  describe "handle_common_error/2" do
    test "handles Ecto changeset errors" do
      changeset = %Changeset{
        valid?: false,
        errors: [email: {"has already been taken", [validation: :unique]}],
        data: %{},
        changes: %{email: "existing@example.com"}
      }

      result = ErrorHandler.handle_common_error(changeset, %{action: :create_user})

      assert %{error: error} = result
      assert error.type == :conflict
      assert error.code == 409
      assert String.contains?(error.message, "unique constraint")
    end

    test "handles Ecto query errors" do
      query_error = %Ecto.QueryError{
        message: "syntax error at or near \"INVALID\""
      }

      result = ErrorHandler.handle_common_error(query_error, %{action: :query_data})

      assert %{error: error} = result
      assert error.type == :unprocessable_entity
      assert error.code == 422
      assert String.contains?(error.message, "Database query error")
    end

    test "handles Ecto constraint errors" do
      constraint_error = %Ecto.ConstraintError{
        type: :foreign_key,
        constraint: "user_bank_accounts_user_bank_login_id_fkey",
        message: "foreign key constraint violated"
      }

      result = ErrorHandler.handle_common_error(constraint_error, %{action: :create_account})

      assert %{error: error} = result
      assert error.type == :conflict
      assert error.code == 409
      assert String.contains?(error.message, "Constraint violation")
    end

    test "handles Ecto no results errors" do
      result = ErrorHandler.handle_common_error(%Ecto.NoResultsError{}, %{action: :get_user})

      assert %{error: error} = result
      assert error.type == :not_found
      assert error.code == 404
      assert error.message == "Resource not found"
    end

    test "handles runtime errors" do
      runtime_error = %RuntimeError{message: "Custom runtime error"}

      result = ErrorHandler.handle_common_error(runtime_error, %{action: :process_data})

      assert %{error: error} = result
      assert error.type == :unprocessable_entity
      assert error.code == 422
      assert error.message == "Custom runtime error"
    end

    test "handles string errors with validation detection" do
      result = ErrorHandler.handle_common_error("Validation error: Invalid email format", %{action: :create_user})

      assert %{error: error} = result
      assert error.type == :validation_error
      assert error.code == 400
    end

    test "handles string errors with authorization detection" do
      result = ErrorHandler.handle_common_error("Access forbidden", %{action: :access_resource})

      assert %{error: error} = result
      assert error.type == :forbidden
      assert error.code == 403
    end

    test "handles string errors with not found detection" do
      result = ErrorHandler.handle_common_error("Invalid UUID format", %{action: :get_resource})

      assert %{error: error} = result
      assert error.type == :not_found
      assert error.code == 404
    end

    test "handles map errors with proper structure" do
      map_error = %{type: :account_inactive, message: "Account is inactive"}

      result = ErrorHandler.handle_common_error(map_error, %{action: :process_payment})

      assert %{error: error} = result
      assert error.type == :account_inactive
      assert error.message == "Account is inactive"
    end

    test "handles map errors without proper structure" do
      map_error = %{some_field: "some_value"}

      result = ErrorHandler.handle_common_error(map_error, %{action: :process_data})

      assert %{error: error} = result
      assert error.type == :internal_server_error
      assert error.code == 500
    end

    test "handles atom errors using hybrid approach" do
      result = ErrorHandler.handle_common_error(:insufficient_funds, %{action: :create_payment})

      assert %{error: error} = result
      assert error.type == :unprocessable_entity
      assert error.code == 422
      assert error.details.reason == :insufficient_funds
      assert error.message == "Insufficient funds for this transaction"
    end

    test "handles unknown errors" do
      unknown_error = %{unexpected: "data"}

      result = ErrorHandler.handle_common_error(unknown_error, %{action: :process_data})

      assert %{error: error} = result
      assert error.type == :internal_server_error
      assert error.code == 500
      assert String.contains?(error.message, "unexpected error")
    end
  end

  describe "create_error_response/3" do
    test "creates error response with all fields" do
      result = ErrorHandler.create_error_response(:validation_error, "Test message", %{field: "value"})

      assert %{error: error} = result
      assert error.type == :validation_error
      assert error.message == "Test message"
      assert error.code == 400
      assert error.details == %{field: "value"}
    end

    test "creates error response without details" do
      result = ErrorHandler.create_error_response(:not_found, "Not found")

      assert %{error: error} = result
      assert error.type == :not_found
      assert error.message == "Not found"
      assert error.code == 404
      assert error.details == %{}
    end

    test "handles unknown error types" do
      result = ErrorHandler.create_error_response(:unknown_error, "Unknown error")

      assert %{error: error} = result
      assert error.type == :unknown_error
      assert error.message == "Unknown error"
      assert error.code == 500  # Default fallback
    end
  end

  describe "create_success_response/2" do
    test "creates success response with data" do
      result = ErrorHandler.create_success_response(%{id: 1, name: "Test"})

      assert result.data == %{id: 1, name: "Test"}
      assert result.success == true
      assert is_struct(result.timestamp, DateTime)
      assert result.metadata == %{}
    end

    test "creates success response with metadata" do
      metadata = %{total_count: 100, page: 1}
      result = ErrorHandler.create_success_response([], metadata)

      assert result.data == []
      assert result.success == true
      assert result.metadata == metadata
    end
  end

  describe "error_types/0" do
    test "returns all error types with correct codes" do
      error_types = ErrorHandler.error_types()

      # Test core HTTP error types
      assert error_types.validation_error == 400
      assert error_types.not_found == 404
      assert error_types.unauthorized == 401
      assert error_types.forbidden == 403
      assert error_types.conflict == 409
      assert error_types.unprocessable_entity == 422
      assert error_types.internal_server_error == 500
      assert error_types.service_unavailable == 503
      assert error_types.timeout == 503

      # Test business-specific error types
      assert error_types.insufficient_funds == 422
      assert error_types.account_inactive == 422
      assert error_types.daily_limit_exceeded == 422
      assert error_types.amount_exceeds_limit == 422
      assert error_types.negative_amount == 422
      assert error_types.invalid_amount_format == 400
      assert error_types.missing_fields == 400
      assert error_types.account_not_found == 404
      assert error_types.user_not_found == 404
      assert error_types.email_already_exists == 409
      assert error_types.invalid_token == 401
      assert error_types.token_expired == 401
      assert error_types.invalid_password == 401
      assert error_types.invalid_credentials == 401
    end
  end


  describe "enhanced string error detection" do
    test "detects additional validation error patterns" do
      validation_messages = [
        "Invalid email format provided",
        "Required field is missing",
        "Missing required parameter",
        "Invalid format for amount"
      ]

      for message <- validation_messages do
        result = ErrorHandler.handle_common_error(message, %{action: :validate})
        assert %{error: error} = result
        assert error.type == :validation_error
        assert error.code == 400
        assert error.message == message
      end
    end

    test "detects additional not found error patterns" do
      not_found_messages = [
        "User not found in database",
        "Resource does not exist",
        "Account not found"
      ]

      for message <- not_found_messages do
        result = ErrorHandler.handle_common_error(message, %{action: :find_resource})
        assert %{error: error} = result
        assert error.type == :not_found
        assert error.code == 404
        assert error.message == message
      end
    end

    test "detects authentication error patterns" do
      auth_messages = [
        "Invalid token provided",
        "Token expired at 2024-01-01",
        "Authentication failed",
        "Invalid credentials"
      ]

      for message <- auth_messages do
        result = ErrorHandler.handle_common_error(message, %{action: :authenticate})
        assert %{error: error} = result
        assert error.type == :unauthorized
        assert error.code == 401
        assert error.message == message
      end
    end

    test "detects conflict error patterns" do
      conflict_messages = [
        "Email already exists in system",
        "Duplicate entry detected",
        "Resource conflict occurred"
      ]

      for message <- conflict_messages do
        result = ErrorHandler.handle_common_error(message, %{action: :create_resource})
        assert %{error: error} = result
        assert error.type == :conflict
        assert error.code == 409
        assert error.message == message
      end
    end

    test "detects service error patterns" do
      service_messages = [
        "Request timeout after 30 seconds",
        "Service temporarily unavailable",
        "External service is down"
      ]

      for message <- service_messages do
        result = ErrorHandler.handle_common_error(message, %{action: :external_call})
        assert %{error: error} = result
        assert error.type == :service_unavailable
        assert error.code == 503
        assert error.message == message
      end
    end
  end


  describe "hybrid approach (recommended for new code)" do
    test "create_hybrid_error_response/4 creates proper error structure" do
      result = ErrorHandler.create_hybrid_error_response(
        :unprocessable_entity,
        "Payment failed",
        :insufficient_funds,
        %{account_id: "acc_123", available: 50.00}
      )

      assert %{error: error} = result
      assert error.type == :unprocessable_entity
      assert error.code == 422
      assert error.message == "Payment failed"
      assert error.details.reason == :insufficient_funds
      assert error.details.account_id == "acc_123"
      assert error.details.available == 50.00
    end

    test "business_error/2 convenience function works correctly" do
      result = ErrorHandler.business_error(:insufficient_funds, %{account_id: "acc_123"})

      assert %{error: error} = result
      assert error.type == :unprocessable_entity
      assert error.code == 422
      assert error.details.reason == :insufficient_funds
      assert error.details.context.account_id == "acc_123"
    end

    test "handle_business_error/2 maps payment errors to 422" do
      payment_errors = [
        :insufficient_funds,
        :account_inactive,
        :daily_limit_exceeded,
        :amount_exceeds_limit,
        :negative_amount
      ]

      for reason <- payment_errors do
        result = ErrorHandler.handle_business_error(reason, %{action: :payment})
        assert %{error: error} = result
        assert error.type == :unprocessable_entity
        assert error.code == 422
        assert error.details.reason == reason
        assert is_binary(error.message)
      end
    end

    test "handle_business_error/2 maps validation errors to 400" do
      validation_errors = [
        :invalid_amount_format,
        :missing_fields
      ]

      for reason <- validation_errors do
        result = ErrorHandler.handle_business_error(reason, %{action: :validation})
        assert %{error: error} = result
        assert error.type == :validation_error
        assert error.code == 400
        assert error.details.reason == reason
        assert is_binary(error.message)
      end
    end

    test "handle_business_error/2 maps not found errors to 404" do
      not_found_errors = [
        :account_not_found,
        :user_not_found
      ]

      for reason <- not_found_errors do
        result = ErrorHandler.handle_business_error(reason, %{action: :lookup})
        assert %{error: error} = result
        assert error.type == :not_found
        assert error.code == 404
        assert error.details.reason == reason
        assert is_binary(error.message)
      end
    end

    test "handle_business_error/2 maps conflict errors to 409" do
      result = ErrorHandler.handle_business_error(:email_already_exists, %{action: :create_user})

      assert %{error: error} = result
      assert error.type == :conflict
      assert error.code == 409
      assert error.details.reason == :email_already_exists
      assert error.message == "Email already exists"
    end

    test "handle_business_error/2 maps authentication errors to 401" do
      auth_errors = [
        :invalid_token,
        :token_expired,
        :invalid_password,
        :invalid_credentials
      ]

      for reason <- auth_errors do
        result = ErrorHandler.handle_business_error(reason, %{action: :authenticate})
        assert %{error: error} = result
        assert error.type == :unauthorized
        assert error.code == 401
        assert error.details.reason == reason
        assert is_binary(error.message)
      end
    end

    test "handle_business_error/2 maps service errors to 503" do
      service_errors = [
        :timeout
      ]

      for reason <- service_errors do
        result = ErrorHandler.handle_business_error(reason, %{action: :service_call})
        assert %{error: error} = result
        assert error.type == :service_unavailable
        assert error.code == 503
        assert error.details.reason == reason
        assert is_binary(error.message)
      end
    end

    test "handle_business_error/2 handles unknown business errors gracefully" do
      result = ErrorHandler.handle_business_error(:unknown_business_error, %{action: :test})

      assert %{error: error} = result
      assert error.type == :internal_server_error
      assert error.code == 500
      assert error.details.reason == :unknown_business_error
      assert String.contains?(error.message, "Unknown business error")
    end

    test "hybrid approach preserves context in details" do
      context = %{action: :process_payment, user_id: "user_123", payment_id: "pay_456"}
      result = ErrorHandler.business_error(:insufficient_funds, context)

      assert %{error: error} = result
      assert error.details.context == context
      assert error.details.reason == :insufficient_funds
    end

    test "hybrid approach allows additional details alongside reason" do
      additional_details = %{
        account_id: "acc_123",
        available_balance: 50.00,
        requested_amount: 100.00,
        currency: "USD"
      }

      result = ErrorHandler.business_error(:insufficient_funds, additional_details)

      assert %{error: error} = result
      assert error.details.reason == :insufficient_funds
      assert error.details.context.account_id == "acc_123"
      assert error.details.context.available_balance == 50.00
      assert error.details.context.requested_amount == 100.00
      assert error.details.context.currency == "USD"
    end

    test "hybrid approach maintains consistent response structure" do
      # Test that all hybrid responses have the same structure
      test_reasons = [:insufficient_funds, :invalid_amount_format, :account_not_found, :email_already_exists, :invalid_token, :timeout]

      for reason <- test_reasons do
        result = ErrorHandler.business_error(reason, %{test: true})
        assert %{error: error} = result

        # Verify consistent structure
        assert Map.has_key?(error, :type)
        assert Map.has_key?(error, :message)
        assert Map.has_key?(error, :code)
        assert Map.has_key?(error, :details)

        # Verify details structure
        assert Map.has_key?(error.details, :reason)
        assert Map.has_key?(error.details, :context)

        # Verify types
        assert is_atom(error.type)
        assert is_binary(error.message)
        assert is_integer(error.code)
        assert is_map(error.details)
        assert is_atom(error.details.reason)
        assert is_map(error.details.context)
      end
    end
  end
end

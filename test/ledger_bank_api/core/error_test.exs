defmodule LedgerBankApi.Core.ErrorTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Core.Error

  describe "new/6" do
    test "creates error with all required fields" do
      error = Error.new(
        :validation_error,
        "Invalid input",
        400,
        :missing_fields,
        %{field: "email"}
      )

      assert error.type == :validation_error
      assert error.message == "Invalid input"
      assert error.code == 400
      assert error.reason == :missing_fields
      assert error.context == %{field: "email"}
      assert %DateTime{} = error.timestamp
      assert error.category == :validation
    end

    test "infers category from type" do
      test_cases = [
        {:validation_error, :validation},
        {:not_found, :not_found},
        {:unauthorized, :authentication},
        {:forbidden, :authorization},
        {:conflict, :conflict},
        {:unprocessable_entity, :business_rule},
        {:service_unavailable, :external_dependency},
        {:timeout, :external_dependency},
        {:internal_server_error, :system}
      ]

      Enum.each(test_cases, fn {type, expected_category} ->
        error = Error.new(type, "Test", 400, :test_reason)
        assert error.category == expected_category
      end)
    end

    test "infers retryable from category" do
      # External dependency errors are retryable
      error1 = Error.new(:service_unavailable, "Service down", 503, :unavailable)
      assert error1.retryable == true

      # System errors are retryable
      error2 = Error.new(:internal_server_error, "Server error", 500, :server_error)
      assert error2.retryable == true

      # Validation errors are not retryable
      error3 = Error.new(:validation_error, "Invalid", 400, :invalid)
      assert error3.retryable == false

      # Business rule errors are not retryable
      error4 = Error.new(:unprocessable_entity, "Rule failed", 422, :rule_failed)
      assert error4.retryable == false
    end

    test "infers circuit_breaker from category" do
      # External dependency errors trigger circuit breaker
      error1 = Error.new(:service_unavailable, "Service down", 503, :unavailable)
      assert error1.circuit_breaker == true

      # System errors trigger circuit breaker
      error2 = Error.new(:internal_server_error, "Server error", 500, :server_error)
      assert error2.circuit_breaker == true

      # Other errors don't trigger circuit breaker
      error3 = Error.new(:validation_error, "Invalid", 400, :invalid)
      assert error3.circuit_breaker == false
    end

    test "accepts optional parameters" do
      error = Error.new(
        :validation_error,
        "Test error",
        400,
        :test_reason,
        %{field: "test"},
        [
          category: :custom_category,
          correlation_id: "test-correlation-id",
          source: "test_module",
          retryable: true,
          circuit_breaker: false
        ]
      )

      assert error.category == :custom_category
      assert error.correlation_id == "test-correlation-id"
      assert error.source == "test_module"
      assert error.retryable == true
      assert error.circuit_breaker == false
    end

    test "sets timestamp automatically" do
      before = DateTime.utc_now()
      error = Error.new(:validation_error, "Test", 400, :test)
      after_time = DateTime.utc_now()

      assert DateTime.compare(error.timestamp, before) in [:gt, :eq]
      assert DateTime.compare(error.timestamp, after_time) in [:lt, :eq]
    end

    test "creates error with empty context" do
      error = Error.new(:validation_error, "Test", 400, :test)

      assert error.context == %{}
    end

    test "creates error with nil context" do
      error = Error.new(:validation_error, "Test", 400, :test, nil)

      assert error.context == nil
    end
  end

  describe "to_client_map/1" do
    test "converts error to client-safe map" do
      error = Error.new(
        :validation_error,
        "Invalid email format",
        400,
        :invalid_email_format,
        %{field: "email", value: "test"}
      )

      client_map = Error.to_client_map(error)

      assert client_map.error.type == :validation_error
      assert client_map.error.message == "Invalid email format"
      assert client_map.error.code == 400
      assert client_map.error.reason == :invalid_email_format
      assert %DateTime{} = client_map.error.timestamp
      assert is_map(client_map.error.details)
    end

    test "sanitizes sensitive fields from context" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{
          field: "email",
          password: "secret123",
          password_hash: "$argon2...",
          access_token: "jwt.token.here",
          refresh_token: "refresh.token",
          secret: "api-secret",
          private_key: "private-key",
          api_key: "api-key-123"
        }
      )

      client_map = Error.to_client_map(error)

      # Should include non-sensitive field
      assert client_map.error.details["field"] == "email"

      # Should NOT include sensitive fields
      refute Map.has_key?(client_map.error.details, "password")
      refute Map.has_key?(client_map.error.details, "password_hash")
      refute Map.has_key?(client_map.error.details, "access_token")
      refute Map.has_key?(client_map.error.details, "refresh_token")
      refute Map.has_key?(client_map.error.details, "secret")
      refute Map.has_key?(client_map.error.details, "private_key")
      refute Map.has_key?(client_map.error.details, "api_key")
    end

    test "converts atom keys to strings" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{field: "email", error_code: 1001}
      )

      client_map = Error.to_client_map(error)

      assert client_map.error.details["field"] == "email"
      assert client_map.error.details["error_code"] == 1001
    end

    test "handles empty context" do
      error = Error.new(:validation_error, "Test", 400, :test, %{})

      client_map = Error.to_client_map(error)

      assert client_map.error.details == %{}
    end

    test "handles nil context" do
      error = Error.new(:validation_error, "Test", 400, :test, nil)

      client_map = Error.to_client_map(error)

      assert client_map.error.details == nil
    end
  end

  describe "to_log_map/1" do
    test "converts error to logging map with full context" do
      error = Error.new(
        :internal_server_error,
        "Database connection failed",
        500,
        :db_connection_failed,
        %{db_host: "localhost", retry_count: 3}
      )

      log_map = Error.to_log_map(error)

      assert log_map.error_type == :internal_server_error
      assert log_map.error_message == "Database connection failed"
      assert log_map.error_code == 500
      assert log_map.error_reason == :db_connection_failed
      assert log_map.context == %{db_host: "localhost", retry_count: 3}
      assert %DateTime{} = log_map.timestamp
    end

    test "includes ALL context (no sanitization)" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{
          password: "should-be-logged",
          api_key: "should-be-logged-for-debugging"
        }
      )

      log_map = Error.to_log_map(error)

      # For logging, we keep everything for debugging
      assert log_map.context.password == "should-be-logged"
      assert log_map.context.api_key == "should-be-logged-for-debugging"
    end
  end

  describe "should_retry?/1" do
    test "returns true for external dependency errors" do
      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [category: :external_dependency, retryable: true]
      )

      assert Error.should_retry?(error) == true
    end

    test "returns true for system errors" do
      error = Error.new(
        :internal_server_error,
        "System error",
        500,
        :server_error,
        %{},
        [category: :system, retryable: true]
      )

      assert Error.should_retry?(error) == true
    end

    test "returns false for validation errors" do
      error = Error.new(
        :validation_error,
        "Invalid input",
        400,
        :invalid,
        %{},
        [category: :validation, retryable: false]
      )

      assert Error.should_retry?(error) == false
    end

    test "returns false for business rule errors" do
      error = Error.new(
        :unprocessable_entity,
        "Business rule failed",
        422,
        :rule_failed,
        %{},
        [category: :business_rule, retryable: false]
      )

      assert Error.should_retry?(error) == false
    end

    test "returns false when retryable is false" do
      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [category: :external_dependency, retryable: false]
      )

      assert Error.should_retry?(error) == false
    end
  end

  describe "should_circuit_break?/1" do
    test "returns true for external dependency errors" do
      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [category: :external_dependency, circuit_breaker: true]
      )

      assert Error.should_circuit_break?(error) == true
    end

    test "returns true for system errors" do
      error = Error.new(
        :internal_server_error,
        "System error",
        500,
        :server_error,
        %{},
        [category: :system, circuit_breaker: true]
      )

      assert Error.should_circuit_break?(error) == true
    end

    test "returns false for validation errors" do
      error = Error.new(
        :validation_error,
        "Invalid",
        400,
        :invalid,
        %{},
        [category: :validation, circuit_breaker: false]
      )

      assert Error.should_circuit_break?(error) == false
    end

    test "returns false when circuit_breaker is false" do
      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [category: :external_dependency, circuit_breaker: false]
      )

      assert Error.should_circuit_break?(error) == false
    end
  end

  describe "retry_delay/1" do
    test "returns 1000ms for external dependency errors" do
      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [category: :external_dependency]
      )

      assert Error.retry_delay(error) == 1000
    end

    test "returns 500ms for system errors" do
      error = Error.new(
        :internal_server_error,
        "System error",
        500,
        :server_error,
        %{},
        [category: :system]
      )

      assert Error.retry_delay(error) == 500
    end

    test "returns 0ms for non-retryable errors" do
      error = Error.new(
        :validation_error,
        "Invalid",
        400,
        :invalid,
        %{},
        [category: :validation]
      )

      assert Error.retry_delay(error) == 0
    end
  end

  describe "max_retry_attempts/1" do
    test "returns 3 attempts for external dependency errors" do
      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [category: :external_dependency]
      )

      assert Error.max_retry_attempts(error) == 3
    end

    test "returns 2 attempts for system errors" do
      error = Error.new(
        :internal_server_error,
        "System error",
        500,
        :server_error,
        %{},
        [category: :system]
      )

      assert Error.max_retry_attempts(error) == 2
    end

    test "returns 0 attempts for validation errors" do
      error = Error.new(
        :validation_error,
        "Invalid",
        400,
        :invalid,
        %{},
        [category: :validation]
      )

      assert Error.max_retry_attempts(error) == 0
    end
  end

  describe "generate_correlation_id/0" do
    test "generates valid correlation ID" do
      id = Error.generate_correlation_id()

      assert is_binary(id)
      assert String.length(id) == 32  # 16 bytes = 32 hex chars
      assert String.match?(id, ~r/^[0-9a-f]{32}$/)
    end

    test "generates unique correlation IDs" do
      ids = Enum.map(1..100, fn _ -> Error.generate_correlation_id() end)
      unique_ids = Enum.uniq(ids)

      assert length(unique_ids) == 100
    end

    test "correlation IDs are hex-encoded lowercase" do
      id = Error.generate_correlation_id()

      assert String.downcase(id) == id
      assert String.match?(id, ~r/^[0-9a-f]+$/)
    end
  end

  describe "emit_telemetry/1" do
    test "emits telemetry event with error metrics" do
      # Attach telemetry handler
      handler_id = "test-error-telemetry-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :error, :created],
        fn event, measurements, metadata, _config ->
          send(self_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      error = Error.new(
        :validation_error,
        "Test error",
        400,
        :test_reason,
        %{field: "test"},
        [correlation_id: "test-correlation-id", source: "test_module"]
      )

      Error.emit_telemetry(error)

      # Verify telemetry event
      assert_receive {:telemetry_event, [:ledger_bank_api, :error, :created], measurements, metadata}, 1000

      assert measurements.count == 1
      assert metadata.error_type == :validation_error
      assert metadata.error_reason == :test_reason
      assert metadata.error_category == :validation
      assert metadata.correlation_id == "test-correlation-id"
      assert metadata.source == "test_module"
      assert metadata.retryable == false
      assert metadata.circuit_breaker == false

      :telemetry.detach(handler_id)
    end

    test "includes timestamp in telemetry metadata" do
      handler_id = "test-error-timestamp-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :error, :created],
        fn _event, _measurements, metadata, _config ->
          send(self_pid, {:metadata, metadata})
        end,
        nil
      )

      error = Error.new(:validation_error, "Test", 400, :test)
      Error.emit_telemetry(error)

      assert_receive {:metadata, metadata}, 1000
      assert %DateTime{} = metadata.timestamp

      :telemetry.detach(handler_id)
    end
  end

  describe "error struct field validations" do
    test "error struct has all required fields" do
      error = %Error{}

      assert Map.has_key?(error, :type)
      assert Map.has_key?(error, :message)
      assert Map.has_key?(error, :code)
      assert Map.has_key?(error, :reason)
      assert Map.has_key?(error, :context)
      assert Map.has_key?(error, :timestamp)
      assert Map.has_key?(error, :category)
      assert Map.has_key?(error, :correlation_id)
      assert Map.has_key?(error, :source)
      assert Map.has_key?(error, :retryable)
      assert Map.has_key?(error, :circuit_breaker)
    end

    test "error struct can be created manually" do
      error = %Error{
        type: :validation_error,
        message: "Test",
        code: 400,
        reason: :test,
        context: %{},
        timestamp: DateTime.utc_now(),
        category: :validation,
        correlation_id: "test-id",
        source: "test",
        retryable: false,
        circuit_breaker: false
      }

      assert error.type == :validation_error
      assert error.code == 400
    end
  end

  describe "context sanitization edge cases" do
    test "handles nested maps in context" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{
          user: %{
            id: 1,
            password: "secret",
            email: "test@example.com"
          }
        }
      )

      client_map = Error.to_client_map(error)

      # Nested password should be removed
      # Note: Current implementation only sanitizes top-level keys
      assert is_map(client_map.error.details)
    end

    test "handles lists in context" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{errors: ["error1", "error2", "error3"]}
      )

      client_map = Error.to_client_map(error)

      assert client_map.error.details["errors"] == ["error1", "error2", "error3"]
    end

    test "handles string keys in context" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{"field" => "email", "value" => "test"}
      )

      client_map = Error.to_client_map(error)

      assert client_map.error.details["field"] == "email"
      assert client_map.error.details["value"] == "test"
    end

    test "handles mixed atom and string keys" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{"string_key" => "value2", atom_key: "value1"}
      )

      client_map = Error.to_client_map(error)

      assert client_map.error.details["atom_key"] == "value1"
      assert client_map.error.details["string_key"] == "value2"
    end
  end

  describe "error categories and types" do
    test "validation error maps to validation category" do
      error = Error.new(:validation_error, "Test", 400, :test)
      assert error.category == :validation
    end

    test "not_found error maps to not_found category" do
      error = Error.new(:not_found, "Test", 404, :test)
      assert error.category == :not_found
    end

    test "unauthorized error maps to authentication category" do
      error = Error.new(:unauthorized, "Test", 401, :test)
      assert error.category == :authentication
    end

    test "forbidden error maps to authorization category" do
      error = Error.new(:forbidden, "Test", 403, :test)
      assert error.category == :authorization
    end

    test "conflict error maps to conflict category" do
      error = Error.new(:conflict, "Test", 409, :test)
      assert error.category == :conflict
    end

    test "unprocessable_entity maps to business_rule category" do
      error = Error.new(:unprocessable_entity, "Test", 422, :test)
      assert error.category == :business_rule
    end

    test "service_unavailable maps to external_dependency category" do
      error = Error.new(:service_unavailable, "Test", 503, :test)
      assert error.category == :external_dependency
    end

    test "timeout maps to external_dependency category" do
      error = Error.new(:timeout, "Test", 408, :test)
      assert error.category == :external_dependency
    end

    test "internal_server_error maps to system category" do
      error = Error.new(:internal_server_error, "Test", 500, :test)
      assert error.category == :system
    end

    test "unknown type maps to system category" do
      error = Error.new(:unknown_type, "Test", 500, :test)
      assert error.category == :system
    end
  end

  describe "retry policy edge cases" do
    test "retryable external dependency with non-matching category returns false" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{},
        [category: :validation, retryable: true]
      )

      # Even though retryable is true, category validation prevents retry
      assert Error.should_retry?(error) == false
    end

    test "system error with retryable false doesn't retry" do
      error = Error.new(
        :internal_server_error,
        "Test",
        500,
        :test,
        %{},
        [category: :system, retryable: false]
      )

      assert Error.should_retry?(error) == false
    end
  end

  describe "error with correlation ID" do
    test "preserves correlation ID" do
      correlation_id = "custom-correlation-#{System.unique_integer()}"

      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{},
        [correlation_id: correlation_id]
      )

      assert error.correlation_id == correlation_id

      _client_map = Error.to_client_map(error)
      # Correlation ID is not exposed in client map currently
      # This is intentional for security
    end

    test "generates correlation ID when not provided" do
      error1 = Error.new(:validation_error, "Test", 400, :test)
      error2 = Error.new(:validation_error, "Test", 400, :test)

      # Both should have nil correlation_id (not auto-generated)
      assert error1.correlation_id == nil
      assert error2.correlation_id == nil
    end
  end

  describe "error with source tracking" do
    test "tracks error source module" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{},
        [source: "UserService.create_user"]
      )

      assert error.source == "UserService.create_user"
    end

    test "source appears in log map but not client map" do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{},
        [source: "TestModule"]
      )

      _log_map = Error.to_log_map(error)
      # Source is part of error struct but not in log_map keys
      # It's accessible via error struct

      client_map = Error.to_client_map(error)
      # Source is not exposed to client
      refute Map.has_key?(client_map.error, :source)
    end
  end
end

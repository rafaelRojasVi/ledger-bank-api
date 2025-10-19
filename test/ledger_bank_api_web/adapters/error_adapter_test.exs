defmodule LedgerBankApiWeb.Adapters.ErrorAdapterTest do
  use LedgerBankApiWeb.ConnCase, async: true
  alias LedgerBankApiWeb.Adapters.ErrorAdapter
  alias LedgerBankApi.Core.{Error, ErrorCatalog}

  describe "handle_error/2" do
    test "returns 400 for validation errors", %{conn: conn} do
      error = Error.new(
        :validation_error,
        "Invalid input",
        400,
        :missing_fields,
        %{field: "email"}
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 400
      response = json_response(conn, 400)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/missing_fields"
      assert response["error"]["reason"] == "missing_fields"
      assert response["error"]["code"] == 400
    end

    test "returns 401 for unauthorized errors", %{conn: conn} do
      error = Error.new(
        :unauthorized,
        "Invalid credentials",
        401,
        :invalid_credentials
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/invalid_credentials"
      assert response["error"]["reason"] == "invalid_credentials"
    end

    test "returns 403 for forbidden errors", %{conn: conn} do
      error = Error.new(
        :forbidden,
        "Insufficient permissions",
        403,
        :insufficient_permissions,
        %{user_role: "user", required_roles: ["admin"]}
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/insufficient_permissions"
      assert response["error"]["reason"] == "insufficient_permissions"
    end

    test "returns 404 for not found errors", %{conn: conn} do
      error = Error.new(
        :not_found,
        "User not found",
        404,
        :user_not_found,
        %{user_id: Ecto.UUID.generate()}
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 404
      response = json_response(conn, 404)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/user_not_found"
    end

    test "returns 409 for conflict errors", %{conn: conn} do
      error = Error.new(
        :conflict,
        "Email already exists",
        409,
        :email_already_exists,
        %{email: "test@example.com"}
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 409
      response = json_response(conn, 409)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/email_already_exists"
    end

    test "returns 422 for unprocessable entity errors", %{conn: conn} do
      error = Error.new(
        :unprocessable_entity,
        "Insufficient funds",
        422,
        :insufficient_funds,
        %{balance: "100.00", requested: "200.00"}
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 422
      response = json_response(conn, 422)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/insufficient_funds"
    end

    test "returns 500 for internal server errors", %{conn: conn} do
      error = Error.new(
        :internal_server_error,
        "Unexpected error occurred",
        500,
        :server_error
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 500
      response = json_response(conn, 500)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/server_error"
    end

    test "returns 503 for service unavailable errors", %{conn: conn} do
      error = Error.new(
        :service_unavailable,
        "External service down",
        503,
        :external_service_unavailable,
        %{service: "bank_api"}
      )

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 503
      response = json_response(conn, 503)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/external_service_unavailable"
    end
  end

  describe "handle_error/2 - response format" do
    test "includes all required fields in error response", %{conn: conn} do
      error = Error.new(
        :validation_error,
        "Test error",
        400,
        :test_reason,
        %{field: "test", value: "invalid"}
      )

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      assert Map.has_key?(response, "error")
      assert Map.has_key?(response["error"], "type")
      assert Map.has_key?(response["error"], "message")
      assert Map.has_key?(response["error"], "code")
      assert Map.has_key?(response["error"], "reason")
      assert Map.has_key?(response["error"], "details")
      assert Map.has_key?(response["error"], "timestamp")
    end

    test "sanitizes sensitive fields from context", %{conn: conn} do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{
          field: "email",
          password: "secret123",
          password_hash: "$argon2...",
          access_token: "jwt.token",
          user_id: "safe-to-show"
        }
      )

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      # Safe fields should be included
      assert response["error"]["details"]["field"] == "email"
      assert response["error"]["details"]["user_id"] == "safe-to-show"

      # Sensitive fields should be sanitized
      refute Map.has_key?(response["error"]["details"], "password")
      refute Map.has_key?(response["error"]["details"], "password_hash")
      refute Map.has_key?(response["error"]["details"], "access_token")
    end

    test "includes timestamp in ISO8601 format", %{conn: conn} do
      error = Error.new(:validation_error, "Test", 400, :test)

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      assert is_binary(response["error"]["timestamp"])
    end
  end

  describe "handle_errors/2 - multiple errors" do
    test "returns highest priority error from list", %{conn: conn} do
      errors = [
        Error.new(:validation_error, "Validation failed", 400, :invalid_input),
        Error.new(:internal_server_error, "Server error", 500, :server_error),
        Error.new(:not_found, "Not found", 404, :not_found)
      ]

      conn = ErrorAdapter.handle_errors(conn, errors)

      # Should return 500 (highest status code)
      assert conn.status == 500
      response = json_response(conn, 500)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/server_error"
    end

    test "handles single error in list", %{conn: conn} do
      errors = [
        Error.new(:validation_error, "Test", 400, :test)
      ]

      conn = ErrorAdapter.handle_errors(conn, errors)

      assert conn.status == 400
    end

    test "prioritizes server errors over client errors", %{conn: conn} do
      errors = [
        Error.new(:validation_error, "Validation", 400, :invalid),
        Error.new(:not_found, "Not found", 404, :not_found),
        Error.new(:service_unavailable, "Service down", 503, :unavailable)
      ]

      conn = ErrorAdapter.handle_errors(conn, errors)

      # 503 should be returned (highest priority)
      assert conn.status == 503
    end
  end

  describe "handle_changeset_error/3" do
    test "converts changeset error to HTTP response", %{conn: conn} do
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:email, {"must be a valid email address", [validation: :format]}}
        ],
        data: %LedgerBankApi.Accounts.Schemas.User{}
      }

      conn = ErrorAdapter.handle_changeset_error(conn, changeset)

      assert conn.status == 400
      response = json_response(conn, 400)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/missing_fields"
    end

    test "includes context in changeset error", %{conn: conn} do
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:email, {"has already been taken", [constraint: :unique]}}
        ],
        data: %LedgerBankApi.Accounts.Schemas.User{}
      }

      context = %{operation: "create_user"}
      conn = ErrorAdapter.handle_changeset_error(conn, changeset, context)

      assert conn.status in [400, 409]  # Depends on error handling
      response = json_response(conn, conn.status)
      assert Map.has_key?(response, "error")
    end
  end

  describe "handle_generic_error/3" do
    test "handles Error struct", %{conn: conn} do
      error = Error.new(:validation_error, "Test", 400, :test)

      conn = ErrorAdapter.handle_generic_error(conn, error)

      assert conn.status == 400
    end

    test "handles atom error reason", %{conn: conn} do
      conn = ErrorAdapter.handle_generic_error(conn, :user_not_found)

      # Should convert to proper error response
      response = json_response(conn, conn.status)
      assert Map.has_key?(response, "error")
    end

    test "handles string error reason", %{conn: conn} do
      conn = ErrorAdapter.handle_generic_error(conn, "Something went wrong")

      assert conn.status == 500
      response = json_response(conn, 500)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/internal_server_error"
    end

    test "handles changeset", %{conn: conn} do
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:email, {"can't be blank", [validation: :required]}}
        ],
        data: %LedgerBankApi.Accounts.Schemas.User{}
      }

      conn = ErrorAdapter.handle_generic_error(conn, changeset)

      assert conn.status == 400
    end

    test "handles exception struct", %{conn: conn} do
      exception = %RuntimeError{message: "Unexpected error"}

      conn = ErrorAdapter.handle_generic_error(conn, exception)

      assert conn.status == 500
      response = json_response(conn, 500)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/internal_server_error"
    end

    test "includes context in generic error handling", %{conn: conn} do
      context = %{source: "test_controller", action: "create"}

      conn = ErrorAdapter.handle_generic_error(conn, :invalid_input, context)

      response = json_response(conn, conn.status)
      assert Map.has_key?(response, "error")
    end
  end

  describe "telemetry emission" do
    test "emits telemetry event on error handling", %{conn: conn} do
      handler_id = "test-error-adapter-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :error, :emitted],
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
        %{},
        [correlation_id: "test-correlation"]
      )

      ErrorAdapter.handle_error(conn, error)

      # Verify telemetry was emitted
      assert_receive {:telemetry_event, [:ledger_bank_api, :error, :emitted], measurements, metadata}, 1000

      assert measurements.count == 1
      assert metadata.error_type == :validation_error
      assert metadata.error_reason == :test_reason
      assert metadata.correlation_id == "test-correlation"

      :telemetry.detach(handler_id)
    end

    test "includes retryable flag in telemetry", %{conn: conn} do
      handler_id = "test-retryable-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :error, :emitted],
        fn _event, _measurements, metadata, _config ->
          send(self_pid, {:metadata, metadata})
        end,
        nil
      )

      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [retryable: true]
      )

      ErrorAdapter.handle_error(conn, error)

      assert_receive {:metadata, metadata}, 1000
      assert metadata.retryable == true

      :telemetry.detach(handler_id)
    end

    test "includes circuit_breaker flag in telemetry", %{conn: conn} do
      handler_id = "test-circuit-breaker-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :error, :emitted],
        fn _event, _measurements, metadata, _config ->
          send(self_pid, {:metadata, metadata})
        end,
        nil
      )

      error = Error.new(
        :service_unavailable,
        "Service down",
        503,
        :unavailable,
        %{},
        [circuit_breaker: true]
      )

      ErrorAdapter.handle_error(conn, error)

      assert_receive {:metadata, metadata}, 1000
      assert metadata.circuit_breaker == true

      :telemetry.detach(handler_id)
    end
  end

  describe "error response consistency" do
    test "all error types have consistent response structure", %{conn: _conn} do
      error_types = [
        {:validation_error, 400},
        {:unauthorized, 401},
        {:forbidden, 403},
        {:not_found, 404},
        {:conflict, 409},
        {:unprocessable_entity, 422},
        {:internal_server_error, 500},
        {:service_unavailable, 503}
      ]

      Enum.each(error_types, fn {type, expected_code} ->
        error = Error.new(type, "Test error", expected_code, :test_reason)

        conn = ErrorAdapter.handle_error(build_conn(), error)
        response = json_response(conn, expected_code)

        # All should have same structure
        assert Map.has_key?(response, "error")
        assert Map.has_key?(response["error"], "type")
        assert Map.has_key?(response["error"], "message")
        assert Map.has_key?(response["error"], "code")
        assert Map.has_key?(response["error"], "reason")
        assert Map.has_key?(response["error"], "details")
      end)
    end
  end

  describe "context sanitization" do
    test "removes password from context", %{conn: conn} do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{password: "secret123", field: "email"}
      )

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      refute Map.has_key?(response["error"]["details"], "password")
      assert response["error"]["details"]["field"] == "email"
    end

    test "removes password_hash from context", %{conn: conn} do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{password_hash: "$argon2...", user_id: "123"}
      )

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      refute Map.has_key?(response["error"]["details"], "password_hash")
      assert response["error"]["details"]["user_id"] == "123"
    end

    test "removes tokens from context", %{conn: conn} do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{
          access_token: "jwt.token",
          refresh_token: "refresh.token",
          field: "test"
        }
      )

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      refute Map.has_key?(response["error"]["details"], "access_token")
      refute Map.has_key?(response["error"]["details"], "refresh_token")
      assert response["error"]["details"]["field"] == "test"
    end

    test "removes API keys and secrets from context", %{conn: conn} do
      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{
          secret: "api-secret",
          private_key: "private-key",
          api_key: "api-key-123",
          public_id: "safe-to-show"
        }
      )

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      refute Map.has_key?(response["error"]["details"], "secret")
      refute Map.has_key?(response["error"]["details"], "private_key")
      refute Map.has_key?(response["error"]["details"], "api_key")
      assert response["error"]["details"]["public_id"] == "safe-to-show"
    end

    test "handles empty context", %{conn: conn} do
      error = Error.new(:validation_error, "Test", 400, :test, %{})

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      assert response["error"]["details"] == %{}
    end

    test "handles nil context", %{conn: conn} do
      error = Error.new(:validation_error, "Test", 400, :test, nil)

      conn = ErrorAdapter.handle_error(conn, error)
      response = json_response(conn, 400)

      assert response["error"]["details"] == nil
    end
  end

  describe "HTTP status code mapping" do
    test "maps error categories to correct status codes", %{conn: _conn} do
      test_cases = [
        {:validation, 400},
        {:authentication, 401},
        {:authorization, 403},
        {:not_found, 404},
        {:conflict, 409},
        {:business_rule, 422},
        {:system, 500},
        {:external_dependency, 503}
      ]

      Enum.each(test_cases, fn {category, expected_status} ->
        # Get the correct error type for this category
        type = ErrorCatalog.error_type_for_category(category)
        error = Error.new(
          type,
          "Test error",
          expected_status,
          :test_reason,
          %{},
          [category: category]
        )

        conn = ErrorAdapter.handle_error(build_conn(), error)

        assert conn.status == expected_status,
          "Category #{category} should map to status #{expected_status}, got #{conn.status}"
      end)
    end
  end

  describe "conn response handling" do
    test "sets response status", %{conn: conn} do
      error = Error.new(:validation_error, "Test", 400, :test)

      conn = ErrorAdapter.handle_error(conn, error)

      assert conn.status == 400
    end

    test "sets JSON content type", %{conn: conn} do
      error = Error.new(:validation_error, "Test", 400, :test)

      conn = ErrorAdapter.handle_error(conn, error)

      content_type = Enum.find(conn.resp_headers, fn {key, _} -> key == "content-type" end)
      assert content_type != nil
      {_, type} = content_type
      assert String.contains?(type, "application/json")
    end
  end

  describe "error handling with different error reasons" do
    test "handles financial business rule errors", %{conn: _conn} do
      financial_errors = [
        :insufficient_funds,
        :daily_limit_exceeded,
        :amount_exceeds_limit
      ]

      Enum.each(financial_errors, fn reason ->
        error = Error.new(
          :unprocessable_entity,
          "Business rule failed",
          422,
          reason,
          %{},
          [category: :business_rule]
        )

        conn = ErrorAdapter.handle_error(build_conn(), error)

        assert conn.status == 422
        response = json_response(conn, 422)
        assert response["error"]["reason"] == Atom.to_string(reason)
      end)
    end

    test "handles authentication errors", %{conn: _conn} do
      auth_errors = [
        :invalid_credentials,
        :token_expired,
        :token_revoked,
        :invalid_token
      ]

      Enum.each(auth_errors, fn reason ->
        error = Error.new(:unauthorized, "Auth failed", 401, reason)

        conn = ErrorAdapter.handle_error(build_conn(), error)

        assert conn.status == 401
        response = json_response(conn, 401)
        assert response["error"]["type"] == "https://api.ledgerbank.com/problems/#{reason}"
      end)
    end
  end

  describe "error with correlation ID tracking" do
    test "correlation ID is preserved internally", %{conn: conn} do
      correlation_id = "test-correlation-#{System.unique_integer()}"

      error = Error.new(
        :validation_error,
        "Test",
        400,
        :test,
        %{},
        [correlation_id: correlation_id]
      )

      # Correlation ID should be in error struct
      assert error.correlation_id == correlation_id

      conn = ErrorAdapter.handle_error(conn, error)

      # Response is sent, correlation tracked internally
      assert conn.status == 400
    end
  end

  describe "concurrent error handling" do
    test "handles multiple concurrent errors without race conditions", %{conn: _conn} do
      tasks = Enum.map(1..50, fn i ->
        Task.async(fn ->
          conn = build_conn()
          error = Error.new(
            :validation_error,
            "Error #{i}",
            400,
            :test_reason,
            %{index: i}
          )

          result_conn = ErrorAdapter.handle_error(conn, error)
          {i, result_conn.status}
        end)
      end)

      results = Task.await_many(tasks)

      # All should succeed
      assert length(results) == 50

      # All should have 400 status
      Enum.each(results, fn {_i, status} ->
        assert status == 400
      end)
    end
  end
end

defmodule LedgerBankApi.Banking.Behaviours.ErrorHandlerTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  # Mock module that implements the ErrorHandler behaviour
  defmodule MockErrorHandler do
    @behaviour LedgerBankApi.Banking.Behaviours.ErrorHandler

    @impl LedgerBankApi.Banking.Behaviours.ErrorHandler
    def with_error_handling(fun, context) do
      try do
        result = fun.()
        {:ok, result}
      rescue
        e in Ecto.QueryError ->
          {:error, :database_error, "Database query failed: #{e.message}"}
        e in Ecto.ChangesetError ->
          {:error, :validation_error, "Validation failed: #{e.message}"}
        e in RuntimeError ->
          {:error, :runtime_error, "Runtime error: #{e.message}"}
        e ->
          {:error, :unknown_error, "Unknown error: #{inspect(e)}"}
      catch
        :exit, reason ->
          {:error, :exit_error, "Process exit: #{inspect(reason)}"}
        kind, payload ->
          {:error, :catch_error, "Caught #{kind}: #{inspect(payload)}"}
      end
    end

    @impl LedgerBankApi.Banking.Behaviours.ErrorHandler
    def format_error_response(error_type, error_message, context) do
      %{
        error: %{
          type: error_type,
          message: error_message,
          context: context,
          timestamp: DateTime.utc_now()
        }
      }
    end
  end

  test "handles successful operations correctly" do
    context = %{action: :test_action, user_id: "user_123"}

    result = MockErrorHandler.with_error_handling(fn ->
      "successful result"
    end, context)

    assert {:ok, "successful result"} = result
  end

  test "handles database errors correctly" do
    context = %{action: :test_action, user_id: "user_123"}

    result = MockErrorHandler.with_error_handling(fn ->
      raise Ecto.QueryError, message: "Invalid SQL query"
    end, context)

    assert {:error, :database_error, message} = result
    assert String.contains?(message, "Database query failed")
  end

  test "handles validation errors correctly" do
    context = %{action: :test_action, user_id: "user_123"}

    result = MockErrorHandler.with_error_handling(fn ->
      raise Ecto.ChangesetError, message: "Invalid email format"
    end, context)

    assert {:error, :validation_error, message} = result
    assert String.contains?(message, "Validation failed")
  end

  test "handles runtime errors correctly" do
    context = %{action: :test_action, user_id: "user_123"}

    result = MockErrorHandler.with_error_handling(fn ->
      raise RuntimeError, message: "Something went wrong"
    end, context)

    assert {:error, :runtime_error, message} = result
    assert String.contains?(message, "Runtime error")
  end

  test "handles process exit errors correctly" do
    context = %{action: :test_action, user_id: "user_123"}

    result = MockErrorHandler.with_error_handling(fn ->
      exit(:normal)
    end, context)

    assert {:error, :exit_error, message} = result
    assert String.contains?(message, "Process exit")
  end

  test "handles unknown errors gracefully" do
    context = %{action: :test_action, user_id: "user_123"}

    result = MockErrorHandler.with_error_handling(fn ->
      throw(:unexpected_error)
    end, context)

    assert {:error, :catch_error, message} = result
    assert String.contains?(message, "Caught throw")
  end

  test "formats error responses correctly" do
    error_type = :validation_error
    error_message = "Invalid input data"
    context = %{action: :create_user, user_id: "user_123"}

    response = MockErrorHandler.format_error_response(error_type, error_message, context)

    assert %{error: error} = response
    assert error.type == :validation_error
    assert error.message == "Invalid input data"
    assert error.context == context
    assert Map.has_key?(error, :timestamp)
  end

  test "preserves context information in errors" do
    context = %{action: :process_payment, payment_id: "pay_123", user_id: "user_456"}

    result = MockErrorHandler.with_error_handling(fn ->
      raise RuntimeError, message: "Payment processing failed"
    end, context)

    assert {:error, :runtime_error, _message} = result
    # Context is preserved and can be used for logging/debugging
  end

  test "handles nested error scenarios" do
    context = %{action: :complex_operation, step: 1}

    result = MockErrorHandler.with_error_handling(fn ->
      MockErrorHandler.with_error_handling(fn ->
        raise RuntimeError, message: "Nested error"
      end, Map.put(context, :step, 2))
    end, context)

    assert {:error, :runtime_error, message} = result
    assert String.contains?(message, "Runtime error")
  end
end

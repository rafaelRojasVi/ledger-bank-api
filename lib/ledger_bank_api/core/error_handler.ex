defmodule LedgerBankApi.Core.ErrorHandler do
  @moduledoc """
  Centralized error handling for the LedgerBankApi application.

  This module is the primary interface for creating standardized error responses.
  It works in conjunction with ErrorCatalog (error taxonomy) and Error (error struct).

  ## Architecture Overview

  The error handling system consists of four main components:

  1. **Error** - Defines the canonical error struct and conversion functions
  2. **ErrorCatalog** - Single source of truth for error taxonomy, categories, and messages
  3. **ErrorHandler** - Creates errors and handles Ecto changesets (this module)
  4. **Validator** - Core validation functions that return simple error reasons
  5. **InputValidator** - Web layer validation that converts Validator results to Error structs

  ## Usage

      # Business errors (recommended)
      {:error, ErrorHandler.business_error(:insufficient_funds, %{account_id: "acc_123"})}

      # With error handling wrapper
      ErrorHandler.with_error_handling(fn -> some_operation() end, %{action: :process_payment})

  ## Core Error Types

  - `:validation_error` → 400 (Bad Request)
  - `:not_found` → 404 (Not Found)
  - `:unauthorized` → 401 (Unauthorized)
  - `:forbidden` → 403 (Forbidden)
  - `:conflict` → 409 (Conflict)
  - `:unprocessable_entity` → 422 (Unprocessable Entity)
  - `:service_unavailable` → 503 (Service Unavailable)
  - `:internal_server_error` → 500 (Internal Server Error)

  ## Business Error Reasons

  **Payment (422):** `:insufficient_funds`, `:account_inactive`, `:daily_limit_exceeded`, `:amount_exceeds_limit`, `:negative_amount`, `:negative_balance`
  **Validation (400):** `:invalid_amount_format`, `:missing_fields`, `:invalid_direction`, `:invalid_email_format`, `:invalid_password_format`
  **Not Found (404):** `:account_not_found`, `:user_not_found`, `:token_not_found`, `:payment_not_found`, `:bank_not_found`
  **Conflict (409):** `:email_already_exists`, `:already_processed`, `:duplicate_transaction`
  **Authentication (401):** `:invalid_token`, `:token_expired`, `:invalid_password`, `:invalid_credentials`, `:token_revoked`, `:invalid_token_type`, `:invalid_issuer`, `:invalid_audience`, `:token_not_yet_valid`, `:missing_required_claims`
  **Service (503):** `:timeout`, `:service_unavailable`, `:bank_api_error`, `:payment_provider_error`
  **System (500):** `:internal_server_error`, `:database_error`, `:configuration_error`
  """

  require Logger
  alias LedgerBankApi.Core.{Error, ErrorCatalog}

  @doc """
  Get error mapping from ErrorCatalog (single source of truth).
  """
  def get_error_mapping(reason) do
    if ErrorCatalog.valid_reason?(reason) do
      category = ErrorCatalog.category_for_reason(reason)
      type = ErrorCatalog.error_type_for_category(category)
      code = ErrorCatalog.http_status_for_category(category)
      message = ErrorCatalog.default_message_for_reason(reason)

      {type, code, message}
    else
      nil
    end
  end

  @doc """
  Creates a standardized business error response using the canonical Error struct.

  This is the recommended way to create business error responses.

  ## Examples

      # Payment business logic
      {:error, ErrorHandler.business_error(:insufficient_funds, %{account_id: "acc_123", available: 50.00, requested: 100.00})}

      # Validation business logic
      {:error, ErrorHandler.business_error(:invalid_amount_format, %{field: "amount", value: "abc"})}

      # Service business logic
      {:error, ErrorHandler.business_error(:timeout, %{service: "payment_provider", timeout_ms: 30000})}
  """
  def business_error(reason, context \\ %{}) when is_atom(reason) and is_map(context) do
    error =
      case get_error_mapping(reason) do
        {type, code, message} ->
          # Use ErrorCatalog for category inference
          category = ErrorCatalog.category_for_reason(reason)

          Error.new(type, message, code, reason, context,
            category: category,
            correlation_id: Error.generate_correlation_id(),
            source: context[:source] || "error_handler"
          )

        nil ->
          # Fallback for unknown business errors
          Logger.warning("Unknown business error reason: #{reason}", %{
            reason: reason,
            context: context
          })

          Error.new(
            :internal_server_error,
            "Unknown business error: #{reason}",
            500,
            reason,
            context,
            category: :system,
            correlation_id: Error.generate_correlation_id(),
            source: context[:source] || "error_handler"
          )
      end

    # Emit telemetry for error tracking
    Error.emit_telemetry(error)
    error
  end

  @doc """
  Creates a retryable error response for transient failures.
  """
  def retryable_error(reason, context \\ %{}) when is_atom(reason) and is_map(context) do
    context_with_retry = Map.put(context, :retryable, true)
    business_error(reason, context_with_retry)
  end

  @doc """
  Handles Ecto changeset errors with intelligent error detection.
  """
  def handle_changeset_error(changeset, context) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    # Analyze changeset to determine the most appropriate error reason
    error_reason = analyze_changeset_errors(changeset, errors)

    # Create context with detailed validation errors
    error_context = Map.put(context, :validation_errors, errors)
    error_context = Map.put(error_context, :changeset_action, changeset.action)
    error_context = Map.put(error_context, :changeset_valid?, changeset.valid?)

    business_error(error_reason, error_context)
  end

  # Private function to analyze changeset errors and determine appropriate error reason
  defp analyze_changeset_errors(_changeset, errors) do
    cond do
      # Check for unique constraint errors first (highest priority)
      has_unique_constraint_error?(errors) ->
        get_unique_constraint_error_reason(errors)

      # Check for format validation errors
      has_format_validation_error?(errors) ->
        get_format_validation_error_reason(errors)

      # Check for length validation errors
      has_length_validation_error?(errors) ->
        get_length_validation_error_reason(errors)

      # Check for inclusion validation errors
      has_inclusion_validation_error?(errors) ->
        get_inclusion_validation_error_reason(errors)

      # Check for custom validation errors
      has_custom_validation_error?(errors) ->
        get_custom_validation_error_reason(errors)

      # Check for required field errors
      has_required_field_error?(errors) ->
        :missing_fields

      # Default fallback
      true ->
        :missing_fields
    end
  end

  # Check for unique constraint errors
  defp has_unique_constraint_error?(errors) do
    Enum.any?(errors, fn {_field, field_errors} ->
      Enum.any?(field_errors, fn error ->
        String.contains?(error, "has already been taken") or
          String.contains?(error, "already exists")
      end)
    end)
  end

  # Get specific unique constraint error reason
  defp get_unique_constraint_error_reason(errors) do
    # Check which field has the unique constraint error
    Enum.find_value(errors, :email_already_exists, fn {field, field_errors} ->
      if Enum.any?(field_errors, &String.contains?(&1, "has already been taken")) do
        case field do
          :email -> :email_already_exists
          _ -> :already_processed
        end
      end
    end)
  end

  # Check for format validation errors
  defp has_format_validation_error?(errors) do
    Enum.any?(errors, fn {_field, field_errors} ->
      Enum.any?(field_errors, fn error ->
        String.contains?(error, "format") or
          String.contains?(error, "invalid")
      end)
    end)
  end

  # Get specific format validation error reason
  defp get_format_validation_error_reason(errors) do
    Enum.find_value(errors, :invalid_email_format, fn {field, field_errors} ->
      if Enum.any?(field_errors, &String.contains?(&1, "format")) do
        case field do
          :email -> :invalid_email_format
          :amount -> :invalid_amount_format
          :direction -> :invalid_direction
          :password -> :invalid_password_format
          :user_id -> :invalid_uuid_format
          :jti -> :invalid_uuid_format
          :full_name -> :invalid_name_format
          _ -> :invalid_email_format
        end
      end
    end)
  end

  # Check for length validation errors
  defp has_length_validation_error?(errors) do
    Enum.any?(errors, fn {_field, field_errors} ->
      Enum.any?(field_errors, fn error ->
        String.contains?(error, "should be") and
          (String.contains?(error, "character") or String.contains?(error, "at least"))
      end)
    end)
  end

  # Get specific length validation error reason
  defp get_length_validation_error_reason(errors) do
    Enum.find_value(errors, :invalid_password_format, fn {field, field_errors} ->
      if Enum.any?(field_errors, &String.contains?(&1, "should be")) do
        case field do
          :password -> :invalid_password_format
          :email -> :invalid_email_format
          :full_name -> :invalid_name_format
          _ -> :invalid_password_format
        end
      end
    end)
  end

  # Check for required field errors
  defp has_required_field_error?(errors) do
    Enum.any?(errors, fn {_field, field_errors} ->
      Enum.any?(field_errors, fn error ->
        String.contains?(error, "can't be blank") or
          String.contains?(error, "is required")
      end)
    end)
  end

  # Check for inclusion validation errors
  defp has_inclusion_validation_error?(errors) do
    Enum.any?(errors, fn {_field, field_errors} ->
      Enum.any?(field_errors, fn error ->
        String.contains?(error, "is invalid")
      end)
    end)
  end

  # Get specific inclusion validation error reason
  defp get_inclusion_validation_error_reason(errors) do
    Enum.find_value(errors, :invalid_inclusion, fn {field, field_errors} ->
      if Enum.any?(field_errors, &String.contains?(&1, "is invalid")) do
        case field do
          :direction -> :invalid_direction
          :status -> :invalid_status
          :role -> :invalid_role
          _ -> :invalid_inclusion
        end
      end
    end)
  end

  # Check for custom validation errors
  defp has_custom_validation_error?(errors) do
    Enum.any?(errors, fn {_field, field_errors} ->
      Enum.any?(field_errors, fn error ->
        String.contains?(error, "cannot be changed") or
          String.contains?(error, "business rule")
      end)
    end)
  end

  # Get specific custom validation error reason
  defp get_custom_validation_error_reason(errors) do
    Enum.find_value(errors, :missing_fields, fn {field, field_errors} ->
      if Enum.any?(field_errors, &String.contains?(&1, "cannot be changed")) do
        case field do
          :role -> :insufficient_permissions
          :status -> :insufficient_permissions
          _ -> :missing_fields
        end
      end
    end)
  end

  @doc """
  Handles Ecto query errors.
  """
  def handle_query_error(%Ecto.QueryError{message: message}, context) do
    business_error(:internal_server_error, Map.put(context, :query_error, message))
  end

  @doc """
  Handles Ecto constraint errors.
  """
  def handle_constraint_error(
        %Ecto.ConstraintError{constraint: constraint, message: message},
        context
      ) do
    business_error(
      :already_processed,
      Map.put(Map.put(context, :constraint_message, message), :constraint, constraint)
    )
  end

  @doc """
  Wraps a function call with error handling, returning standardized Error structs.
  """
  def with_error_handling(fun, context \\ %{}) do
    try do
      case fun.() do
        {:ok, result} ->
          # Check if result is already a properly formatted paginated response
          if is_map(result) and Map.has_key?(result, :data) and Map.has_key?(result, :pagination) do
            {:ok, result}
          else
            {:ok, result}
          end

        {:error, %LedgerBankApi.Core.Error{} = error_response} ->
          # Already a proper Error, return as is
          {:error, error_response}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, handle_changeset_error(changeset, context)}

        {:error, %Ecto.ConstraintError{} = constraint_error} ->
          {:error, handle_constraint_error(constraint_error, context)}

        {:error, reason} when is_atom(reason) ->
          # Convert atom reason to Error
          {:error, business_error(reason, context)}

        {:error, reason} when is_binary(reason) ->
          # Convert string reason to Error
          {:error,
           business_error(:internal_server_error, Map.put(context, :original_message, reason))}

        {:error, reason} when is_map(reason) ->
          # Convert map reason to Error
          {:error,
           business_error(:internal_server_error, Map.put(context, :original_error, reason))}

        result ->
          {:ok, result}
      end
    rescue
      error ->
        # Log error with structured logging (sanitized)
        Logger.error("Error in with_error_handling", %{
          error_type: error.__struct__,
          error_message: Exception.message(error),
          context: sanitize_log_context(context)
        })

        case error do
          %Ecto.ConstraintError{} ->
            {:error, handle_constraint_error(error, context)}

          %Ecto.NoResultsError{} ->
            {:error, business_error(:not_found, context)}

          %RuntimeError{message: message} ->
            {:error,
             business_error(:internal_server_error, Map.put(context, :original_message, message))}

          error when is_binary(error) ->
            {:error,
             business_error(:internal_server_error, Map.put(context, :original_message, error))}

          _ ->
            {:error,
             business_error(
               :internal_server_error,
               Map.put(context, :original_error, inspect(error))
             )}
        end
    end
  end

  @doc """
  Gets the HTTP status code for an error type from ErrorCatalog.
  """
  def get_error_code(type) do
    # Find the category that maps to this error type
    category =
      Enum.find(ErrorCatalog.categories(), fn cat ->
        ErrorCatalog.error_type_for_category(cat) == type
      end)

    case category do
      nil -> 500
      cat -> ErrorCatalog.http_status_for_category(cat)
    end
  end

  @doc """
  Gets the HTTP status code for an error type (direct mapping).
  """
  def get_error_code_for_type(type) do
    case type do
      :validation_error -> 400
      :not_found -> 404
      :unauthorized -> 401
      :forbidden -> 403
      :conflict -> 409
      :unprocessable_entity -> 422
      :service_unavailable -> 503
      :internal_server_error -> 500
      _ -> 500
    end
  end

  @doc """
  Checks if an error is retryable based on its reason.
  """
  def retryable_error?(%LedgerBankApi.Core.Error{reason: reason}) do
    reason in [:timeout, :service_unavailable]
  end

  def retryable_error?(reason) when is_atom(reason) do
    reason in [:timeout, :service_unavailable]
  end

  def retryable_error?(_), do: false

  @doc """
  Wraps a function call with retry logic for transient errors.
  """
  def with_retry(fun, context \\ %{}, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    # milliseconds
    base_delay = Keyword.get(opts, :base_delay, 100)
    backoff_multiplier = Keyword.get(opts, :backoff_multiplier, 2)

    do_with_retry(fun, context, max_retries, base_delay, backoff_multiplier, 0)
  end

  defp do_with_retry(fun, _context, max_retries, _base_delay, _backoff_multiplier, attempt)
       when attempt >= max_retries do
    # Final attempt failed
    fun.()
  end

  defp do_with_retry(fun, context, max_retries, base_delay, backoff_multiplier, attempt) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, %Error{reason: reason} = error} ->
        if retryable_error?(reason) do
          delay = (base_delay * :math.pow(backoff_multiplier, attempt)) |> round()

          Logger.info("Retrying operation after #{delay}ms", %{
            attempt: attempt + 1,
            max_retries: max_retries,
            reason: reason,
            context: context
          })

          Process.sleep(delay)
          do_with_retry(fun, context, max_retries, base_delay, backoff_multiplier, attempt + 1)
        else
          {:error, error}
        end

      {:error, error} ->
        # Non-Error error, don't retry
        {:error, error}
    end
  end

  @doc """
  Executes a function with circuit breaker pattern for external service calls.
  """
  def with_circuit_breaker(fun, context \\ %{}, opts \\ []) do
    _failure_threshold = Keyword.get(opts, :failure_threshold, 5)
    # 30 seconds
    timeout = Keyword.get(opts, :timeout, 30000)
    # 1 minute
    _reset_timeout = Keyword.get(opts, :reset_timeout, 60000)

    # For now, implement a simple version - in production, you'd use a proper circuit breaker library
    try do
      # Set a timeout for the operation
      Task.await(Task.async(fun), timeout)
    rescue
      error ->
        Logger.error("Circuit breaker: Operation failed", %{
          error: inspect(error),
          context: context
        })

        # In a real implementation, you'd track failures and implement the circuit breaker logic
        {:error,
         retryable_error(:service_unavailable, Map.put(context, :circuit_breaker_failure, true))}
    end
  end

  @doc """
  Creates a timeout error for operations that take too long.
  """
  def timeout_error(context \\ %{}, timeout_ms \\ 30000) do
    business_error(:timeout, Map.put(context, :timeout_ms, timeout_ms))
  end

  @doc """
  Creates a standardized error response for controllers.
  This is a convenience function that creates an Error struct and converts it to client format.

  ## Examples

      # Simple error
      ErrorHandler.create_error_response(:not_found, "User not found")

      # Error with context
      ErrorHandler.create_error_response(:validation_error, "Invalid input", %{field: "email"})
  """
  def create_error_response(type, message, context \\ %{})
      when is_atom(type) and is_binary(message) and is_map(context) do
    # Convert type to a reason for business_error
    reason =
      case type do
        :validation_error -> :missing_fields
        :not_found -> :user_not_found
        :unauthorized -> :invalid_token
        :forbidden -> :forbidden
        :conflict -> :already_processed
        :unprocessable_entity -> :internal_server_error
        :service_unavailable -> :service_unavailable
        :internal_server_error -> :internal_server_error
        _ -> :internal_server_error
      end

    # Create the error using business_error for consistency
    error = business_error(reason, Map.put(context, :custom_message, message))

    # Convert to client format
    Error.to_client_map(error)
  end

  @doc """
  Creates a success response for controllers.

  ## Examples

      # Simple success
      ErrorHandler.create_success_response(%{id: 1, name: "User"})

      # Success with metadata
      ErrorHandler.create_success_response(users, %{total_count: 100, page: 1})
  """
  def create_success_response(data, metadata \\ %{}) do
    %{
      data: data,
      success: true,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  # Private helper to sanitize context for logging (removes sensitive data)
  defp sanitize_log_context(context) when is_map(context) do
    context
    |> Map.drop([
      :password,
      :password_hash,
      :access_token,
      :refresh_token,
      :secret,
      :private_key,
      :api_key
    ])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      # Convert atom keys to strings and sanitize values
      string_key = if is_atom(key), do: Atom.to_string(key), else: key

      # Sanitize potentially sensitive values
      sanitized_value =
        case value do
          %{password: _} -> "[REDACTED: contains password]"
          %{access_token: _} -> "[REDACTED: contains token]"
          %{secret: _} -> "[REDACTED: contains secret]"
          _ -> value
        end

      Map.put(acc, string_key, sanitized_value)
    end)
  end

  defp sanitize_log_context(context), do: context
end

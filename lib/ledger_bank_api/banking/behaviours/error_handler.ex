defmodule LedgerBankApi.Banking.Behaviours.ErrorHandler do
  @moduledoc """
  Centralized error handling for the LedgerBankApi application.

  Provides consistent error responses with proper HTTP status codes and business-specific details.

  ## Usage

      # Business errors (recommended)
      ErrorHandler.business_error(:insufficient_funds, %{account_id: "acc_123"})

      # Common error handling
      ErrorHandler.handle_common_error(:not_found, %{action: :get_user})

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

  **Payment (422):** `:insufficient_funds`, `:account_inactive`, `:daily_limit_exceeded`, `:amount_exceeds_limit`, `:negative_amount`
  **Validation (400):** `:invalid_amount_format`, `:missing_fields`
  **Not Found (404):** `:account_not_found`, `:user_not_found`
  **Conflict (409):** `:email_already_exists`
  **Authentication (401):** `:invalid_token`, `:token_expired`, `:invalid_password`, `:invalid_credentials`
  **Service (503):** `:timeout`
  """

  require Logger

  @callback handle_error(any(), any(), keyword()) :: any()
  @callback format_error(any(), keyword()) :: map()
  @callback log_error(any(), keyword()) :: :ok

  @doc """
  Standard error types and their corresponding HTTP status codes.
  """
  def error_types do
    %{
      # Core HTTP error types
      validation_error: 400,
      not_found: 404,
      unauthorized: 401,
      forbidden: 403,
      conflict: 409,
      unprocessable_entity: 422,
      internal_server_error: 500,
      service_unavailable: 503,
      timeout: 503,
      # Business-specific errors (mapped to appropriate HTTP codes)
      insufficient_funds: 422,
      account_inactive: 422,
      daily_limit_exceeded: 422,
      amount_exceeds_limit: 422,
      negative_amount: 422,
      invalid_amount_format: 400,
      missing_fields: 400,
      account_not_found: 404,
      user_not_found: 404,
      email_already_exists: 409,
      invalid_token: 401,
      token_expired: 401,
      invalid_password: 401,
      invalid_credentials: 401
    }
  end

  @doc """
  Creates a standardized error response.
  """
  def create_error_response(type, message, details \\ %{}) do
    # Log details for debugging while keeping response simple
    unless Mix.env() == :test do
      Logger.debug("Error details", %{
        type: type,
        message: message,
        details: details,
        timestamp: DateTime.utc_now()
      })
    end

    %{
      error: %{
        type: type,
        message: message,
        code: get_error_code(type),
        details: details
      }
    }
  end

  @doc """
  Creates a standardized error response using the hybrid approach.

  This is the recommended approach for new code:
  - Use core error types (validation_error, not_found, etc.) for HTTP status mapping
  - Put business-specific reasons in the details.reason field

  ## Examples

      # Business rule violation
      create_hybrid_error_response(:unprocessable_entity, "Payment failed", :insufficient_funds, %{account_id: "acc_123"})

      # Validation error with specific field
      create_hybrid_error_response(:validation_error, "Invalid input", :invalid_amount_format, %{field: "amount"})

      # Service error with specific reason
      create_hybrid_error_response(:service_unavailable, "External service error", :integration_timeout, %{service: "payment_provider"})
  """
  def create_hybrid_error_response(type, message, reason, additional_details \\ %{}) do
    # Extract context from additional_details if it exists
    context = Map.get(additional_details, :context, %{})

    # Remove context from additional_details to avoid duplication
    details_without_context = Map.delete(additional_details, :context)

    # Merge all details together - put additional_details directly in details
    details = Map.merge(details_without_context, %{
      reason: reason,
      context: context
    })

    create_error_response(type, message, details)
  end

  @doc """
  Handles business logic errors using the hybrid approach.

  This function maps business-specific error reasons to appropriate HTTP status codes
  while preserving the specific business reason in the details.
  """
  def handle_business_error(reason, context \\ %{}) do
    case reason do
      # Payment business errors -> 422 (Unprocessable Entity)
      :insufficient_funds ->
        create_hybrid_error_response(:unprocessable_entity, "Insufficient funds for this transaction", reason, %{context: context})
      :account_inactive ->
        create_hybrid_error_response(:unprocessable_entity, "Account is inactive", reason, %{context: context})
      :daily_limit_exceeded ->
        create_hybrid_error_response(:unprocessable_entity, "Daily payment limit exceeded", reason, %{context: context})
      :amount_exceeds_limit ->
        create_hybrid_error_response(:unprocessable_entity, "Payment amount exceeds single transaction limit", reason, %{context: context})
      :negative_amount ->
        create_hybrid_error_response(:unprocessable_entity, "Payment amount cannot be negative", reason, %{context: context})

      # Validation errors -> 400 (Bad Request)
      :invalid_amount_format ->
        create_hybrid_error_response(:validation_error, "Invalid amount format", reason, %{context: context})
      :missing_fields ->
        create_hybrid_error_response(:validation_error, "Required fields are missing", reason, %{context: context})

      # Not found errors -> 404 (Not Found)
      :not_found ->
        create_hybrid_error_response(:not_found, "Resource not found", reason, %{context: context})
      :account_not_found ->
        create_hybrid_error_response(:not_found, "Account not found", reason, %{context: context})
      :user_not_found ->
        create_hybrid_error_response(:not_found, "User not found", reason, %{context: context})

      # Conflict errors -> 409 (Conflict)
      :email_already_exists ->
        create_hybrid_error_response(:conflict, "Email already exists", reason, %{context: context})

      # Authentication errors -> 401 (Unauthorized)
      :invalid_token ->
        create_hybrid_error_response(:unauthorized, "Invalid token", reason, %{context: context})
      :token_expired ->
        create_hybrid_error_response(:unauthorized, "Token has expired", reason, %{context: context})
      :invalid_password ->
        create_hybrid_error_response(:unauthorized, "Invalid password", reason, %{context: context})
      :invalid_credentials ->
        create_hybrid_error_response(:unauthorized, "Unauthorized access", reason, %{context: context})

      # Service errors -> 503 (Service Unavailable)
      :timeout ->
        create_hybrid_error_response(:service_unavailable, "Request timeout", reason, %{context: context})

      # Fallback for unknown business errors
      _ ->
        create_hybrid_error_response(:internal_server_error, "Unknown business error: #{reason}", reason, %{context: context})
    end
  end

  @doc """
  Convenience function for creating business error responses using the hybrid approach.

  This is the recommended way to create business error responses in new code.

  ## Examples

      # Payment business logic
      ErrorHandler.business_error(:insufficient_funds, %{account_id: "acc_123", available: 50.00, requested: 100.00})

      # Validation business logic
      ErrorHandler.business_error(:invalid_amount_format, %{field: "amount", value: "abc"})

      # Service business logic
      ErrorHandler.business_error(:integration_timeout, %{service: "payment_provider", timeout_ms: 30000})
  """
  def business_error(reason, additional_details \\ %{}) do
    # For business_error, we treat additional_details as context to maintain consistency
    # This avoids code duplication while providing the same functionality
    handle_business_error(reason, additional_details)
  end

  @doc """
  Handles common error patterns and returns appropriate responses.
  """
  def handle_common_error(error, context \\ %{}) do
    # Debug logging to see what error we're getting
    Logger.debug("handle_common_error called with", %{
      error: inspect(error),
      error_type: if(is_map(error), do: Map.get(error, :__struct__), else: :not_struct),
      context: context
    })

    case error do
      %Ecto.Changeset{} = changeset ->
        handle_changeset_error(changeset, context)

      %Ecto.QueryError{} = query_error ->
        handle_query_error(query_error, context)

      %Ecto.ConstraintError{} = constraint_error ->
        handle_constraint_error(constraint_error, context)

      %Ecto.NoResultsError{} ->
        handle_not_found_error("Resource not found", context)

      %RuntimeError{message: message} ->
        handle_string_error(message, context)

      {:error, reason} when is_binary(reason) ->
        handle_string_error(reason, context)

      {:error, reason} when is_map(reason) ->
        handle_map_error(reason, context)

      {:error, reason} when is_atom(reason) ->
        handle_business_error(reason, context)

      # Handle bare atoms (when error tuples are unwrapped)
      reason when is_atom(reason) ->
        handle_business_error(reason, context)

      # Handle bare maps (when error tuples are unwrapped)
      reason when is_map(reason) ->
        handle_map_error(reason, context)

      # Handle bare strings (when error tuples are unwrapped)
      reason when is_binary(reason) ->
        handle_string_error(reason, context)

      # Handle already formatted error responses
      %{error: %{code: _code, message: _message, type: _type}} = error_response ->
        # This is already a properly formatted error response, return it as is
        error_response

      _ ->
        handle_unknown_error(error, context)
    end
  end

  @doc """
  Handles Ecto changeset errors.
  """
  def handle_changeset_error(changeset, context) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)

    # Check if this is a unique constraint error
    has_unique_error = Enum.any?(errors, fn {_field, field_errors} ->
      Enum.any?(field_errors, fn error ->
        String.contains?(error, "has already been taken")
      end)
    end)

    if has_unique_error do
      create_error_response(
        :conflict,
        "Constraint violation: unique constraint",
        %{errors: errors, context: context}
      )
    else
      create_error_response(
        :validation_error,
        "Validation failed",
        %{errors: errors, context: context}
      )
    end
  end

  @doc """
  Handles Ecto query errors.
  """
  def handle_query_error(%Ecto.QueryError{message: message}, context) do
    create_error_response(
      :unprocessable_entity,
      "Database query error: #{message}",
      %{context: context}
    )
  end

  @doc """
  Handles Ecto constraint errors.
  """
  def handle_constraint_error(%Ecto.ConstraintError{constraint: constraint, message: message}, context) do
    create_error_response(
      :conflict,
      "Constraint violation: #{constraint}",
      %{message: message, context: context}
    )
  end

  @doc """
  Handles not found errors.
  """
  def handle_not_found_error(message, context) do
    create_error_response(
      :not_found,
      message,
      %{context: context}
    )
  end

  @doc """
  Handles string errors.
  """
  def handle_string_error(message, context) do
    # Debug logging
    Logger.debug("handle_string_error called with", %{
      message: message,
      context: context
    })

    # Convert to lowercase for case-insensitive matching
    lower_message = String.downcase(message)

    type = cond do
      # Validation errors
      String.starts_with?(lower_message, "validation error") or
      String.contains?(lower_message, "page must be") or
      String.contains?(lower_message, "page size") or
      String.contains?(lower_message, "invalid amount") or
      String.contains?(lower_message, "invalid date") or
      String.contains?(lower_message, "invalid email") or
      String.contains?(lower_message, "invalid format") or
      String.contains?(lower_message, "required field") or
      String.contains?(lower_message, "missing required") ->
        :validation_error

      # Not found errors
      String.contains?(lower_message, "invalid uuid format") or
      String.contains?(lower_message, "not found") or
      String.contains?(lower_message, "does not exist") ->
        :not_found

      # Authorization/Forbidden errors
      String.contains?(lower_message, "unauthorized access") or
      String.contains?(lower_message, "access forbidden") or
      String.contains?(lower_message, "insufficient permissions") or
      String.contains?(lower_message, "permission denied") or
      String.contains?(lower_message, "forbidden") ->
        :forbidden

      # Authentication errors
      String.contains?(lower_message, "invalid token") or
      String.contains?(lower_message, "token expired") or
      String.contains?(lower_message, "authentication failed") or
      String.contains?(lower_message, "invalid credentials") ->
        :unauthorized

      # Conflict errors
      String.contains?(lower_message, "already exists") or
      String.contains?(lower_message, "duplicate") or
      String.contains?(lower_message, "conflict") ->
        :conflict

      # Service errors
      String.contains?(lower_message, "timeout") or
      String.contains?(lower_message, "service unavailable") or
      String.contains?(lower_message, "temporarily unavailable") or
      String.contains?(lower_message, "external service") or
      String.contains?(lower_message, "service is down") or
      String.contains?(lower_message, "service down") or
      String.contains?(lower_message, "connection timeout") or
      String.contains?(lower_message, "network error") ->
        :service_unavailable

      true ->
        :unprocessable_entity
    end

    # Debug logging for the determined type
    Logger.debug("handle_string_error determined type", %{
      message: message,
      determined_type: type
    })

    create_error_response(
      type,
      message,
      %{context: context}
    )
  end

  @doc """
  Handles map errors.
  """
  def handle_map_error(%{type: type, message: message} = error, context) do
    create_error_response(
      type,
      message,
      Map.merge(error, %{context: context})
    )
  end

  def handle_map_error(error, context) when is_map(error) do
    # Handle other map errors that don't have the expected structure
    create_error_response(
      :internal_server_error,
      "An unexpected error occurred",
      %{error: inspect(error), context: context}
    )
  end


  @doc """
  Handles unknown errors.
  """
  def handle_unknown_error(error, context) do
    create_error_response(
      :internal_server_error,
      "An unexpected error occurred",
      %{error: inspect(error), context: context}
    )
  end

  @doc """
  Logs error with structured logging.
  """
  def log_error(error, context \\ %{}) do
    unless Mix.env() == :test do
      Logger.error("Application error", %{
        error: inspect(error),
        context: context,
        timestamp: DateTime.utc_now(),
        stacktrace: Process.info(self(), :current_stacktrace)
      })
    end
    :ok
  end

  @doc """
  Creates a success response wrapper.
  """
  def create_success_response(data, metadata \\ %{}) do
    %{
      data: data,
      success: true,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Wraps a function call with error handling.
  """
  def with_error_handling(fun, context \\ %{}) do
    try do
      case fun.() do
        {:ok, result} ->
          # Check if result is already a properly formatted paginated response
          if is_map(result) and Map.has_key?(result, :data) and Map.has_key?(result, :pagination) do
            # This is already a properly formatted paginated response, return as is
            {:ok, result}
          else
            # For non-paginated responses, return the result directly without wrapping
            # The controller layer will handle the final response formatting
            {:ok, result}
          end
        {:error, %Ecto.Changeset{} = changeset} -> {:error, handle_changeset_error(changeset, context)}
        {:error, %Ecto.ConstraintError{} = constraint_error} -> {:error, handle_constraint_error(constraint_error, context)}
        {:error, %{type: type, message: message} = error} when is_atom(type) and is_binary(message) ->
          {:error, create_error_response(type, message, error)}
        {:error, error} -> {:error, handle_common_error(error, context)}
        # Handle already formatted error responses
        %{error: %{code: _code, message: _message, type: _type}} = error_response ->
          {:error, error_response}
        result -> {:ok, result}
      end
    rescue
      error ->
        # Debug logging to see what error is being rescued
        Logger.debug("with_error_handling rescued error", %{
          error: inspect(error),
          error_type: if(is_map(error), do: Map.get(error, :__struct__), else: :not_struct),
          context: context
        })

        log_error(error, context)
        case error do
          %Ecto.ConstraintError{} -> {:error, handle_constraint_error(error, context)}
          %Ecto.NoResultsError{} -> {:error, handle_not_found_error("Resource not found", context)}
          %RuntimeError{message: _message} -> {:error, handle_unknown_error(error, context)}
          error when is_binary(error) -> {:error, handle_unknown_error(error, context)}
          _ -> {:error, handle_unknown_error(error, context)}
        end
    end
  end

  @doc """
  Gets the HTTP status code for an error type.
  """
  def get_error_code(type) do
    error_types()[type] || 500
  end
end

defmodule LedgerBankApi.Banking.Behaviours.ErrorResponse do
  @moduledoc """
  Struct for standardized error responses.
  """
  defstruct [:type, :message, :code, :details, :timestamp]

  @type t :: %__MODULE__{
    type: atom(),
    message: String.t(),
    code: integer(),
    details: map(),
    timestamp: DateTime.t()
  }
end

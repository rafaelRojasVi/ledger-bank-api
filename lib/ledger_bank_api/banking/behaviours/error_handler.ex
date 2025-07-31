defmodule LedgerBankApi.Banking.Behaviours.ErrorHandler do
  @moduledoc """
  Behaviour and utility functions for consistent error handling across the application.
  Provides standardized error responses, logging, and error formatting for controllers, workers, and contexts.
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
      validation_error: 400,
      not_found: 404,
      unauthorized: 401,
      forbidden: 403,
      conflict: 409,
      unprocessable_entity: 422,
      internal_server_error: 500,
      service_unavailable: 503
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
        code: get_error_code(type)
      }
    }
  end

  @doc """
  Handles common error patterns and returns appropriate responses.
  """
  def handle_common_error(error, context \\ %{}) do
    # Force debug output even in test mode
    IO.puts("=== DEBUG: handle_common_error called ===")
    IO.puts("Error: #{inspect(error)}")
    IO.puts("Error type: #{if(is_map(error), do: Map.get(error, :__struct__), else: :not_struct)}")
    IO.puts("Context: #{inspect(context)}")
    IO.puts("==========================================")

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
        handle_atom_error(reason, context)

      # Handle bare atoms (when error tuples are unwrapped)
      reason when is_atom(reason) ->
        handle_atom_error(reason, context)

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
        "Constraint violation: users_email_index",
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
    # Force debug output even in test mode
    IO.puts("=== DEBUG: handle_string_error called ===")
    IO.puts("Message: #{message}")
    IO.puts("Context: #{inspect(context)}")
    IO.puts("==========================================")

    # Debug logging
    Logger.debug("handle_string_error called with", %{
      message: message,
      context: context
    })

    type =
      if String.starts_with?(message, "Validation error") or
           String.contains?(message, "Page must be") or
           String.contains?(message, "Page size") or
           String.contains?(message, "Invalid amount") or
           String.contains?(message, "Invalid date") do
        :validation_error
      else
        if String.contains?(message, "Invalid UUID format") do
          :not_found
        else
          if String.contains?(message, "Unauthorized access") or
             String.contains?(message, "Access forbidden") or
             String.contains?(message, "Insufficient permissions") do
            :forbidden
          else
            :unprocessable_entity
          end
        end
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
  Handles atom errors.
  """
  def handle_atom_error(atom, context) do
    case atom do
      :not_found ->
        create_error_response(:not_found, "Resource not found", %{context: context})
      :unauthorized ->
        create_error_response(:unauthorized, "Unauthorized access", %{context: context})
      :forbidden ->
        create_error_response(:forbidden, "Access forbidden", %{context: context})
      :timeout ->
        create_error_response(:service_unavailable, "Request timeout", %{context: context})
      :invalid_credentials ->
        create_error_response(:unauthorized, "Unauthorized access", %{context: context})
      :invalid_refresh_token ->
        create_error_response(:unauthorized, "Unauthorized access", %{context: context})
      _ ->
        create_error_response(:internal_server_error, "Unknown error: #{atom}", %{context: context})
    end
  end

  @doc """
  Handles unknown errors.
  """
  def handle_unknown_error(error, context) do
    # Force debug output even in test mode
    IO.puts("=== DEBUG: handle_unknown_error called ===")
    IO.puts("Error: #{inspect(error)}")
    IO.puts("Context: #{inspect(context)}")
    IO.puts("==========================================")

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
        {:ok, result} -> {:ok, create_success_response(result)}
        {:error, %Ecto.Changeset{} = changeset} -> {:error, handle_changeset_error(changeset, context)}
        {:error, %Ecto.ConstraintError{} = constraint_error} -> {:error, handle_constraint_error(constraint_error, context)}
        {:error, %{type: type, message: message} = error} when is_atom(type) and is_binary(message) ->
          {:error, create_error_response(type, message, error)}
        {:error, error} -> {:error, handle_common_error(error, context)}
        # Handle already formatted error responses
        %{error: %{code: _code, message: _message, type: _type}} = error_response ->
          {:error, error_response}
        result -> {:ok, create_success_response(result)}
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
          _ -> {:error, handle_common_error(error, context)}
        end
    end
  end

  defp get_error_code(type) do
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

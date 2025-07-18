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
    %{
      error: %{
        type: type,
        message: message,
        code: get_error_code(type),
        details: details,
        timestamp: DateTime.utc_now()
      }
    }
  end

  @doc """
  Handles common error patterns and returns appropriate responses.
  """
  def handle_common_error(error, context \\ %{}) do
    case error do
      %Ecto.Changeset{} = changeset ->
        handle_changeset_error(changeset, context)

      %Ecto.QueryError{} = query_error ->
        handle_query_error(query_error, context)

      %Ecto.ConstraintError{} = constraint_error ->
        handle_constraint_error(constraint_error, context)

      {:error, reason} when is_binary(reason) ->
        handle_string_error(reason, context)

      {:error, reason} when is_map(reason) ->
        handle_map_error(reason, context)

      {:error, reason} when is_atom(reason) ->
        handle_atom_error(reason, context)

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

    create_error_response(
      :validation_error,
      "Validation failed",
      %{errors: errors, context: context}
    )
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
  Handles string errors.
  """
  def handle_string_error(message, context) do
    create_error_response(
      :unprocessable_entity,
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
      _ ->
        create_error_response(:internal_server_error, "Unknown error: #{atom}", %{context: context})
    end
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
    Logger.error("Application error", %{
      error: inspect(error),
      context: context,
      timestamp: DateTime.utc_now(),
      stacktrace: Process.info(self(), :current_stacktrace)
    })
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
        {:error, error} -> {:error, handle_common_error({:error, error}, context)}
        result -> {:ok, create_success_response(result)}
      end
    rescue
      error ->
        log_error(error, context)
        {:error, handle_common_error(error, context)}
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

defmodule LedgerBankApi.Helpers.ResponseHelpers do
  @moduledoc """
  Simple response helpers for consistent API responses.
  """

  @doc """
  Handles database operation results consistently.
  """
  def handle_result({:ok, data}), do: {:ok, data}
  def handle_result({:error, changeset}) when is_struct(changeset, Ecto.Changeset) do
    {:error, format_changeset_errors(changeset)}
  end
  def handle_result({:error, reason}), do: {:error, reason}

  @doc """
  Creates a simple success response.
  """
  def success_response(data, metadata \\ %{}) do
    %{
      data: data,
      success: true,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a simple error response.
  """
  def error_response(type, message, details \\ nil) do
    %{
      error: %{
        type: type,
        message: message,
        details: details
      },
      success: false,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Creates a paginated response with metadata.
  """
  def paginated_response(data, pagination, metadata \\ %{}) do
    %{
      data: data,
      pagination: pagination,
      success: true,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a list response with count.
  """
  def list_response(data, count, metadata \\ %{}) do
    %{
      data: data,
      count: count,
      success: true,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a single resource response.
  """
  def resource_response(resource, metadata \\ %{}) do
    %{
      data: resource,
      success: true,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a message response.
  """
  def message_response(message, metadata \\ %{}) do
    %{
      message: message,
      success: true,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a validation error response.
  """
  def validation_error_response(errors, metadata \\ %{}) do
    %{
      error: %{
        type: :validation_error,
        message: "Validation failed",
        errors: errors
      },
      success: false,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a not found error response.
  """
  def not_found_response(resource_type, metadata \\ %{}) do
    %{
      error: %{
        type: :not_found,
        message: "#{resource_type} not found"
      },
      success: false,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates an unauthorized error response.
  """
  def unauthorized_response(message \\ "Unauthorized access", metadata \\ %{}) do
    %{
      error: %{
        type: :unauthorized,
        message: message
      },
      success: false,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a forbidden error response.
  """
  def forbidden_response(message \\ "Access forbidden", metadata \\ %{}) do
    %{
      error: %{
        type: :forbidden,
        message: message
      },
      success: false,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a conflict error response.
  """
  def conflict_response(message, metadata \\ %{}) do
    %{
      error: %{
        type: :conflict,
        message: message
      },
      success: false,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Creates a server error response.
  """
  def server_error_response(message \\ "Internal server error", metadata \\ %{}) do
    %{
      error: %{
        type: :internal_server_error,
        message: message
      },
      success: false,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
  end

  # Private helper functions

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

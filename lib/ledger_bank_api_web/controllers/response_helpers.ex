defmodule LedgerBankApiWeb.ResponseHelpers do
  @moduledoc """
  Helper functions for creating standardized API responses.
  """

  @doc """
  Helper to create a success response with optional message.
  """
  def success_response(data, message \\ nil) do
    response = %{data: data}
    if message, do: Map.put(response, :message, message), else: response
  end

  @doc """
  Helper to create a job queuing response.
  """
  def job_response(job_type, resource_id, message \\ nil) do
    success_response(%{
      message: message || "#{job_type} initiated",
      "#{job_type}_id": resource_id,
      status: "queued"
    })
  end

  @doc """
  Helper to create a paginated response.
  """
  def paginated_response(data, pagination_metadata) do
    %{
      data: data,
      pagination: pagination_metadata
    }
  end

  @doc """
  Helper to create an error response.
  """
  def error_response(type, message, details \\ %{}) do
    %{
      error: %{
        type: type,
        message: message,
        details: details,
        timestamp: DateTime.utc_now()
      }
    }
  end
end

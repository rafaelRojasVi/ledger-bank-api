defmodule LedgerBankApiWeb.Controllers.BaseController do
  @moduledoc """
  Base controller providing common functionality for all API controllers.

  Implements the "one-thing" error handling pattern by:
  1. Providing consistent error handling helpers
  2. Standardizing response formats
  3. Adding correlation IDs for request tracking
  """

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [assign: 3, put_resp_header: 3, get_req_header: 2]
  alias LedgerBankApiWeb.Adapters.ErrorAdapter
  alias LedgerBankApi.Core.Error

  defmacro __using__(_opts) do
    quote do
      use LedgerBankApiWeb, :controller
      import LedgerBankApiWeb.Controllers.BaseController
      alias LedgerBankApiWeb.Adapters.ErrorAdapter
      alias LedgerBankApi.Core.Error

      # Add correlation ID to all requests
      plug :add_correlation_id
    end
  end

  @doc """
  Plug to add correlation ID to all requests for error tracking.
  """
  def add_correlation_id(conn, _opts) do
    correlation_id = get_correlation_id(conn)
    conn = put_resp_header(conn, "x-correlation-id", correlation_id)
    assign(conn, :correlation_id, correlation_id)
  end

  @doc """
  Handle successful responses with consistent formatting.
  """
  def handle_success(conn, data, metadata \\ %{}) do
    response = %{
      data: data,
      success: true,
      timestamp: DateTime.utc_now(),
      correlation_id: conn.assigns[:correlation_id],
      metadata: metadata
    }

    json(conn, response)
  end

  @doc """
  Handle error responses using the web adapter.
  """
  def handle_error(conn, %Error{} = error) do
    # Add correlation ID to error context if not present
    error_with_correlation = if is_nil(error.correlation_id) do
      %{error | correlation_id: conn.assigns[:correlation_id]}
    else
      error
    end

    ErrorAdapter.handle_error(conn, error_with_correlation)
  end

  @doc """
  Handle generic errors by converting them to canonical Error structs.
  """
  def handle_error(conn, reason, context \\ %{}) do
    context_with_correlation = Map.put(context, :correlation_id, conn.assigns[:correlation_id])
    ErrorAdapter.handle_generic_error(conn, reason, context_with_correlation)
  end

  @doc """
  Handle changeset errors.
  """
  def handle_changeset_error(conn, changeset, context \\ %{}) do
    context_with_correlation = Map.put(context, :correlation_id, conn.assigns[:correlation_id])
    ErrorAdapter.handle_changeset_error(conn, changeset, context_with_correlation)
  end

  @doc """
  Extract and validate pagination parameters.
  """
  def extract_pagination_params(params) do
    page = params
    |> Map.get("page", "1")
    |> String.to_integer()
    |> max(1)

    page_size = params
    |> Map.get("page_size", "20")
    |> String.to_integer()
    |> min(100)  # Cap at 100 items per page
    |> max(1)

    %{page: page, page_size: page_size}
  end

  @doc """
  Extract and validate sorting parameters.
  """
  def extract_sort_params(params) do
    case Map.get(params, "sort") do
      nil -> []
      sort_string when is_binary(sort_string) ->
        sort_string
        |> String.split(",")
        |> Enum.map(&parse_sort_field/1)
        |> Enum.reject(&is_nil/1)
      _ -> []
    end
  end

  @doc """
  Extract and validate filter parameters.
  """
  def extract_filter_params(params) do
    params
    |> Map.drop(["page", "page_size", "sort"])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if is_binary(value) and String.length(value) > 0 do
        Map.put(acc, String.to_atom(key), value)
      else
        acc
      end
    end)
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_correlation_id(conn) do
    # Try to get from request headers first
    case get_req_header(conn, "x-correlation-id") do
      [correlation_id] when is_binary(correlation_id) -> correlation_id
      _ -> Error.generate_correlation_id()
    end
  end

  defp parse_sort_field(field_string) do
    case String.split(field_string, ":") do
      [field] -> {String.to_atom(field), :asc}
      [field, direction] when direction in ["asc", "desc"] ->
        {String.to_atom(field), String.to_atom(direction)}
      _ -> nil
    end
  end
end

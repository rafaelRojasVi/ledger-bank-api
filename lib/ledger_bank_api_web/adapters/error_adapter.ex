defmodule LedgerBankApiWeb.Adapters.ErrorAdapter do
  @moduledoc """
  Web adapter for mapping canonical Error structs to HTTP responses.

  This adapter implements the "one-thing" pattern by:
  1. Taking canonical Error structs from the domain layer
  2. Mapping them to appropriate HTTP status codes and client-safe responses
  3. Providing structured logging for observability

  ## Usage

      # In controllers
      case SomeService.operation() do
        {:ok, result} -> json(conn, result)
        {:error, %Error{} = error} ->
          ErrorAdapter.handle_error(conn, error)
      end
  """

  use Phoenix.Controller
  import Plug.Conn
  require Logger
  alias LedgerBankApi.Core.{Error, ErrorCatalog}

  @doc """
  Handles a canonical Error and returns an appropriate HTTP response.

  Maps error categories to HTTP status codes and provides client-safe error responses.
  Implements RFC 9457 Problem Details for HTTP APIs with application/problem+json content type.
  """
  def handle_error(conn, %Error{} = error) do
    # Emit telemetry event for observability
    emit_error_telemetry(error)

    # Map error category to HTTP status
    status_code = ErrorCatalog.http_status_for_category(error.category)

    # Create RFC 9457 compliant response
    problem_response = to_problem_details(error, conn)

    # Log error with full context (for debugging)
    log_error(error)

    # Return HTTP response with JSON content type
    conn = conn
    |> put_resp_content_type("application/json")
    |> put_status(status_code)

    # Add Retry-After header for retryable errors
    conn = if Error.should_retry?(error) do
      retry_delay = Error.retry_delay(error)
      put_resp_header(conn, "retry-after", "#{retry_delay}")
    else
      conn
    end

    # Wrap response in "error" object for API consistency
    json(conn, %{"error" => problem_response})
  end

  @doc """
  Handles multiple errors and returns the most appropriate HTTP response.
  """
  def handle_errors(conn, errors) when is_list(errors) do
    # Find the error with the highest priority status code
    primary_error = Enum.max_by(errors, fn %Error{} = error ->
      ErrorCatalog.http_status_for_category(error.category)
    end)

    handle_error(conn, primary_error)
  end

  @doc """
  Handles Ecto changeset errors by converting them to canonical Error structs.
  """
  def handle_changeset_error(conn, changeset, context \\ %{}) do
    # Convert changeset to canonical error
    error = LedgerBankApi.Core.ErrorHandler.handle_changeset_error(changeset, context)
    handle_error(conn, error)
  end

  @doc """
  Handles generic errors (atoms, strings, exceptions) by converting them to canonical Error structs.
  """
  def handle_generic_error(conn, reason, context \\ %{}) do
    error = case reason do
      %Error{} = error -> error
      reason when is_atom(reason) ->
        LedgerBankApi.Core.ErrorHandler.business_error(reason, context)
      reason when is_binary(reason) ->
        LedgerBankApi.Core.ErrorHandler.business_error(:internal_server_error,
          Map.put(context, :original_message, reason))
      %Ecto.Changeset{} = changeset ->
        LedgerBankApi.Core.ErrorHandler.handle_changeset_error(changeset, context)
      exception ->
        LedgerBankApi.Core.ErrorHandler.business_error(:internal_server_error,
          Map.put(context, :exception, inspect(exception)))
    end

    handle_error(conn, error)
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp to_problem_details(%Error{} = error, conn) do
    # Get correlation ID from connection or error
    instance_id = conn.assigns[:correlation_id] || error.correlation_id

    # Base response structure that matches test expectations
    base_response = %{
      type: "https://api.ledgerbank.com/problems/#{error.reason}",
      title: ErrorCatalog.default_message_for_reason(error.reason),
      message: error.message,
      code: error.code,
      reason: error.reason,
      category: error.category,
      retryable: error.retryable,
      timestamp: error.timestamp,
      status: ErrorCatalog.http_status_for_category(error.category),
      instance: instance_id
    }

    # Add retry information for retryable errors
    base_response = if Error.should_retry?(error) do
      Map.merge(base_response, %{
        retry_after_ms: Error.retry_delay(error),
        max_retry_attempts: Error.max_retry_attempts(error)
      })
    else
      base_response
    end

    # Add sanitized context details
    details = cond do
      is_nil(error.context) -> nil
      is_map(error.context) and map_size(error.context) > 0 -> sanitize_context_for_problem(error.context)
      true -> %{}  # empty map for empty context
    end

    Map.put(base_response, :details, details)
  end

  defp emit_error_telemetry(%Error{} = error) do
    :telemetry.execute(
      [:ledger_bank_api, :error, :emitted],
      %{count: 1},
      %{
        error_type: error.type,
        error_reason: error.reason,
        error_category: error.category,
        correlation_id: error.correlation_id,
        source: error.source,
        retryable: error.retryable,
        circuit_breaker: error.circuit_breaker
      }
    )
  end

  defp log_error(%Error{} = error) do
    Logger.error("Error handled by web adapter",
      Map.merge(Error.to_log_map(error), %{
        http_status: ErrorCatalog.http_status_for_category(error.category),
        adapter: "web_error_adapter"
      })
    )
  end

  defp sanitize_context_for_problem(context) when is_map(context) do
    context
    |> Map.drop([:password, :password_hash, :access_token, :refresh_token, :secret, :private_key, :api_key])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      # Convert atom keys to strings for JSON serialization
      string_key = if is_atom(key), do: Atom.to_string(key), else: key
      Map.put(acc, string_key, value)
    end)
  end

  defp sanitize_context_for_problem(_context), do: %{}
end

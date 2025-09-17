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
  """
  def handle_error(conn, %Error{} = error) do
    # Emit telemetry event for observability
    emit_error_telemetry(error)

    # Map error category to HTTP status
    status_code = ErrorCatalog.http_status_for_category(error.category)

    # Create client-safe response
    client_response = Error.to_client_map(error)

    # Log error with full context (for debugging)
    log_error(error)

    # Return HTTP response
    conn
    |> put_status(status_code)
    |> json(client_response)
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
end

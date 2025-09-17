defmodule LedgerBankApiWeb.Plugs.ErrorHandler do
  @moduledoc """
  Global error handling plug for the web layer.

  Catches unhandled errors and converts them to appropriate HTTP responses
  using the canonical Error struct and web adapter.
  """

  require Logger
  alias LedgerBankApiWeb.Adapters.ErrorAdapter

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
  rescue
    error ->
      Logger.error("Unhandled error in web layer", %{
        error: inspect(error),
        stacktrace: Exception.format_stacktrace(__STACKTRACE__),
        path: conn.request_path,
        method: conn.method
      })

      # Convert to canonical error and handle
      error = LedgerBankApi.Core.ErrorHandler.business_error(:internal_server_error, %{
        exception: inspect(error),
        path: conn.request_path,
        method: conn.method
      })

      # Use the web adapter to handle the error
      ErrorAdapter.handle_error(conn, error)
  end
end

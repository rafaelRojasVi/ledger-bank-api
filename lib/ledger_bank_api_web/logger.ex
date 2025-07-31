defmodule LedgerBankApiWeb.Logger do
  @moduledoc """
  Structured logging for the banking API.
  Provides consistent logging format and levels.
  """

  require Logger

  @doc """
  Logs API request information.
  """
  def log_request(conn, start_time) do
    duration = System.monotonic_time(:millisecond) - start_time
    user_id = get_in(conn.assigns, [:current_user_id])

    Logger.info("API Request", %{
      method: conn.method,
      path: conn.request_path,
      status: conn.status,
      duration_ms: duration,
      user_id: user_id,
      remote_ip: format_ip(conn.remote_ip),
      user_agent: get_req_header(conn, "user-agent") |> List.first()
    })
  end

  @doc """
  Logs API error information.
  """
  def log_error(conn, error, start_time) do
    duration = System.monotonic_time(:millisecond) - start_time
    user_id = get_in(conn.assigns, [:current_user_id])

    Logger.error("API Error", %{
      method: conn.method,
      path: conn.request_path,
      status: conn.status,
      duration_ms: duration,
      user_id: user_id,
      error: Exception.message(error),
      stacktrace: format_stacktrace(error),
      remote_ip: format_ip(conn.remote_ip)
    })
  end

  @doc """
  Logs rate limiting events.
  """
  def log_rate_limit_exceeded(client_id, limit) do
    Logger.warning("Rate limit exceeded", %{
      client_id: client_id,
      limit: limit,
      event: "rate_limit_exceeded"
    })
  end

  @doc """
  Logs database operations.
  """
  def log_db_operation(operation, table, duration_ms, success) do
    level = if success, do: :info, else: :error

    Logger.log(level, "Database operation", %{
      operation: operation,
      table: table,
      duration_ms: duration_ms,
      success: success,
      event: "db_operation"
    })
  end

  @doc """
  Logs external API calls.
  """
  def log_external_api_call(endpoint, duration_ms, success, error \\ nil) do
    level = if success, do: :info, else: :error

    Logger.log(level, "External API call", %{
      endpoint: endpoint,
      duration_ms: duration_ms,
      success: success,
      error: error,
      event: "external_api_call"
    })
  end

  @doc """
  Logs business events.
  """
  def log_business_event(event_type, data) do
    Logger.info("Business event", %{
      event_type: event_type,
      data: data,
      event: "business_event"
    })
  end

  @doc """
  Logs security events.
  """
  def log_security_event(event_type, data) do
    Logger.warning("Security event", %{
      event_type: event_type,
      data: data,
      event: "security_event"
    })
  end

  # Private helper functions

  defp format_ip(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp format_stacktrace(_error) do
    try do
      Exception.format_stacktrace()
    rescue
      _ -> "Stacktrace not available"
    end
  end

  defp get_req_header(conn, header) do
    Plug.Conn.get_req_header(conn, header)
  end
end

defmodule LedgerBankApiWeb.Logger do
  @moduledoc """
  Structured logging module for the LedgerBankApi application.

  Provides consistent, structured logging across the application with:
  - Request/response logging
  - Error tracking
  - Performance monitoring
  - Business event logging
  - Audit trail logging
  """

  require Logger

  @doc """
  Logs incoming HTTP requests with structured data.
  """
  def log_request(conn, start_time) do
    Logger.info("Request started", %{
      method: conn.method,
      path: conn.request_path,
      query_params: conn.query_params,
      correlation_id: conn.assigns[:correlation_id],
      user_agent: get_req_header(conn, "user-agent") |> List.first(),
      content_type: get_req_header(conn, "content-type") |> List.first(),
      content_length: get_req_header(conn, "content-length") |> List.first(),
      remote_ip: get_remote_ip(conn),
      timestamp: DateTime.utc_now(),
      start_time: start_time
    })
  end

  @doc """
  Logs outgoing HTTP responses with structured data.
  """
  def log_response(conn, start_time) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    Logger.info("Request completed", %{
      method: conn.method,
      path: conn.request_path,
      status: conn.status,
      duration_ms: duration,
      correlation_id: conn.assigns[:correlation_id],
      response_size: get_response_size(conn),
      timestamp: DateTime.utc_now(),
      user_id: get_user_id(conn)
    })
  end

  @doc """
  Logs business events with structured data.
  """
  def log_business_event(event_type, data \\ %{}) do
    Logger.info("Business event", %{
      event_type: event_type,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  @doc """
  Logs authentication events.
  """
  def log_auth_event(event_type, user_id, data \\ %{}) do
    Logger.info("Authentication event", %{
      event_type: event_type,
      user_id: user_id,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  @doc """
  Logs authorization events.
  """
  def log_authz_event(event_type, user_id, resource, data \\ %{}) do
    Logger.info("Authorization event", %{
      event_type: event_type,
      user_id: user_id,
      resource: resource,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  @doc """
  Logs database operations with performance metrics.
  """
  def log_db_operation(operation, table, duration_ms, data \\ %{}) do
    Logger.debug("Database operation", %{
      operation: operation,
      table: table,
      duration_ms: duration_ms,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  @doc """
  Logs external service calls.
  """
  def log_external_service_call(service, endpoint, method, duration_ms, status, data \\ %{}) do
    Logger.info("External service call", %{
      service: service,
      endpoint: endpoint,
      method: method,
      duration_ms: duration_ms,
      status: status,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  @doc """
  Logs performance metrics.
  """
  def log_performance_metric(metric_name, value, unit, data \\ %{}) do
    Logger.info("Performance metric", %{
      metric_name: metric_name,
      value: value,
      unit: unit,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  @doc """
  Logs audit events for compliance and security.
  """
  def log_audit_event(event_type, user_id, resource, action, data \\ %{}) do
    Logger.info("Audit event", %{
      event_type: event_type,
      user_id: user_id,
      resource: resource,
      action: action,
      data: sanitize_audit_data(data),
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  @doc """
  Logs security events.
  """
  def log_security_event(event_type, severity, data \\ %{}) do
    Logger.warning("Security event", %{
      event_type: event_type,
      severity: severity,
      data: sanitize_security_data(data),
      timestamp: DateTime.utc_now(),
      correlation_id: data[:correlation_id]
    })
  end

  # Private helper functions

  defp get_req_header(conn, header) do
    Plug.Conn.get_req_header(conn, header)
  end

  defp get_remote_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      _ ->
        case get_req_header(conn, "x-real-ip") do
          [ip] -> ip
          _ -> to_string(:inet.ntoa(conn.remote_ip))
        end
    end
  end

  defp get_response_size(conn) do
    case conn.resp_body do
      body when is_binary(body) -> byte_size(body)
      _ -> 0
    end
  end

  defp get_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp sanitize_audit_data(data) do
    data
    |> Map.drop([:password, :password_hash, :access_token, :refresh_token, :secret, :private_key, :api_key])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      # Convert atom keys to strings and sanitize values
      string_key = if is_atom(key), do: Atom.to_string(key), else: key

      # Sanitize potentially sensitive values
      sanitized_value = case value do
        %{password: _} -> "[REDACTED: contains password]"
        %{access_token: _} -> "[REDACTED: contains token]"
        %{secret: _} -> "[REDACTED: contains secret]"
        _ -> value
      end

      Map.put(acc, string_key, sanitized_value)
    end)
  end

  defp sanitize_security_data(data) do
    data
    |> Map.drop([:password, :password_hash, :access_token, :refresh_token, :secret, :private_key, :api_key])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      # Convert atom keys to strings and sanitize values
      string_key = if is_atom(key), do: Atom.to_string(key), else: key

      # Sanitize potentially sensitive values
      sanitized_value = case value do
        %{password: _} -> "[REDACTED: contains password]"
        %{access_token: _} -> "[REDACTED: contains token]"
        %{secret: _} -> "[REDACTED: contains secret]"
        _ -> value
      end

      Map.put(acc, string_key, sanitized_value)
    end)
  end
end
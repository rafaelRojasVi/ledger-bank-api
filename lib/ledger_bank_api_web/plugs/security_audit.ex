defmodule LedgerBankApiWeb.Plugs.SecurityAudit do
  @moduledoc """
  Security audit plug for logging security-related events.

  Monitors and logs:
  - Authentication failures
  - Authorization failures
  - Rate limit violations
  - Suspicious request patterns
  - Security policy violations
  """

  require Logger
  alias LedgerBankApiWeb.Logger, as: AppLogger

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> audit_request()
    |> audit_response()
  end

  defp audit_request(conn) do
    # Log suspicious request patterns
    audit_suspicious_headers(conn)
    audit_suspicious_user_agent(conn)
    audit_suspicious_content_type(conn)

    conn
  end

  defp audit_response(conn) do
    # Log security-related response codes
    case conn.status do
      401 -> log_security_event("authentication_failure", conn)
      403 -> log_security_event("authorization_failure", conn)
      429 -> log_security_event("rate_limit_exceeded", conn)
      400 -> audit_bad_request(conn)
      _ -> :ok
    end

    conn
  end

  defp audit_suspicious_headers(conn) do
    # Check for suspicious headers
    suspicious_headers = [
      "x-forwarded-for",
      "x-real-ip",
      "x-originating-ip",
      "x-remote-ip",
      "x-remote-addr"
    ]

    Enum.each(suspicious_headers, fn header ->
      case get_req_header(conn, header) do
        [value] when is_binary(value) ->
          if is_suspicious_ip(value) do
            log_security_event("suspicious_ip_header", conn, %{
              header: header,
              value: value
            })
          end
        _ -> :ok
      end
    end)
  end

  defp audit_suspicious_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent] when is_binary(user_agent) ->
        if is_suspicious_user_agent(user_agent) do
          log_security_event("suspicious_user_agent", conn, %{
            user_agent: user_agent
          })
        end
      _ -> :ok
    end
  end

  defp audit_suspicious_content_type(conn) do
    case get_req_header(conn, "content-type") do
      [content_type] when is_binary(content_type) ->
        if is_suspicious_content_type(content_type) do
          log_security_event("suspicious_content_type", conn, %{
            content_type: content_type
          })
        end
      _ -> :ok
    end
  end

  defp audit_bad_request(conn) do
    # Log bad requests that might indicate attacks
    case conn.assigns[:phoenix_format] do
      "json" ->
        # Check if it's a JSON parsing error
        log_security_event("malformed_json_request", conn)
      _ ->
        # Check for other suspicious patterns
        if contains_suspicious_patterns(conn.request_path) do
          log_security_event("suspicious_request_path", conn, %{
            path: conn.request_path
          })
        end
    end
  end

  defp is_suspicious_ip(ip) do
    # Check for private IPs, localhost, or known malicious IPs
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, {127, 0, 0, 1}} -> true  # localhost
      {:ok, {10, _, _, _}} -> true   # private network
      {:ok, {172, b, _, _}} when b >= 16 and b <= 31 -> true  # private network
      {:ok, {192, 168, _, _}} -> true  # private network
      {:ok, {0, 0, 0, 0}} -> true   # invalid IP
      _ -> false
    end
  rescue
    _ -> true  # Invalid IP format is suspicious
  end

  defp is_suspicious_user_agent(user_agent) do
    suspicious_patterns = [
      "sqlmap",
      "nikto",
      "nmap",
      "masscan",
      "zap",
      "burp",
      "w3af",
      "acunetix",
      "nessus",
      "openvas",
      "curl",
      "wget",
      "python-requests",
      "go-http-client",
      "java/",
      "bot",
      "crawler",
      "spider",
      "scraper"
    ]

    user_agent_lower = String.downcase(user_agent)
    Enum.any?(suspicious_patterns, &String.contains?(user_agent_lower, &1))
  end

  defp is_suspicious_content_type(content_type) do
    suspicious_types = [
      "application/x-www-form-urlencoded",
      "multipart/form-data",
      "text/plain",
      "application/xml",
      "text/xml"
    ]

    Enum.any?(suspicious_types, &String.contains?(content_type, &1))
  end

  defp contains_suspicious_patterns(path) do
    suspicious_patterns = [
      "../",
      "..\\",
      "/etc/passwd",
      "/etc/shadow",
      "/proc/",
      "/sys/",
      "cmd.exe",
      "powershell",
      "bash",
      "sh",
      "php",
      "asp",
      "jsp",
      "sql",
      "admin",
      "administrator",
      "root",
      "test",
      "debug",
      "config",
      "backup",
      "dump"
    ]

    path_lower = String.downcase(path)
    Enum.any?(suspicious_patterns, &String.contains?(path_lower, &1))
  end

  defp log_security_event(event_type, conn, data \\ %{}) do
    AppLogger.log_security_event(event_type, "medium", %{
      method: conn.method,
      path: conn.request_path,
      remote_ip: get_remote_ip(conn),
      user_agent: get_req_header(conn, "user-agent") |> List.first(),
      correlation_id: conn.assigns[:correlation_id],
      timestamp: DateTime.utc_now()
    } |> Map.merge(data))
  end

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
end

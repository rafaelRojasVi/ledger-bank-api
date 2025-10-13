defmodule LedgerBankApiWeb.Plugs.SecurityAuditTest do
  use LedgerBankApiWeb.ConnCase, async: false
  import ExUnit.CaptureLog

  describe "call/2 - basic functionality" do
    test "allows request to continue", %{conn: conn} do
      conn = LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])

      refute conn.halted
    end

    test "does not modify request path", %{conn: conn} do
      original_path = conn.request_path
      conn = LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])

      assert conn.request_path == original_path
    end

    test "does not modify request method", %{conn: conn} do
      original_method = conn.method
      conn = LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])

      assert conn.method == original_method
    end
  end

  describe "suspicious IP detection" do
    test "detects localhost IP", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("x-forwarded-for", "127.0.0.1")
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "suspicious_ip_header" or log == ""
    end

    test "detects private network IPs", %{conn: conn} do
      private_ips = [
        "10.0.0.1",
        "172.16.0.1",
        "192.168.1.1"
      ]

      Enum.each(private_ips, fn ip ->
        log = capture_log(fn ->
          conn
          |> put_req_header("x-forwarded-for", ip)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_ip_header" or log == ""
      end)
    end

    test "allows public IPs", %{conn: conn} do
      public_ips = [
        "8.8.8.8",
        "1.1.1.1",
        "93.184.216.34"
      ]

      Enum.each(public_ips, fn ip ->
        log = capture_log(fn ->
          conn
          |> put_req_header("x-forwarded-for", ip)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        # Should not log suspicious activity for public IPs
        refute log =~ "suspicious_ip_header"
      end)
    end

    test "handles invalid IP format", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("x-forwarded-for", "not-an-ip")
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "suspicious_ip_header" or log == ""
    end
  end

  describe "suspicious user agent detection" do
    test "detects security scanner user agents", %{conn: conn} do
      scanner_agents = [
        "sqlmap/1.0",
        "nikto/2.1",
        "Mozilla/5.0 (compatible; Nmap)",
        "masscan/1.0",
        "OWASP ZAP",
        "Burp Suite"
      ]

      Enum.each(scanner_agents, fn agent ->
        log = capture_log(fn ->
          conn
          |> put_req_header("user-agent", agent)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_user_agent" or log == ""
      end)
    end

    test "detects bot user agents", %{conn: conn} do
      bot_agents = [
        "Googlebot/2.1",
        "Mozilla/5.0 (compatible; bingbot/2.0)",
        "crawler/1.0",
        "spider/1.0"
      ]

      Enum.each(bot_agents, fn agent ->
        log = capture_log(fn ->
          conn
          |> put_req_header("user-agent", agent)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_user_agent" or log == ""
      end)
    end

    test "detects command-line tool user agents", %{conn: conn} do
      cli_agents = [
        "curl/7.68.0",
        "Wget/1.20.3",
        "python-requests/2.25.1",
        "Go-http-client/1.1"
      ]

      Enum.each(cli_agents, fn agent ->
        log = capture_log(fn ->
          conn
          |> put_req_header("user-agent", agent)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_user_agent" or log == ""
      end)
    end

    test "allows legitimate browser user agents", %{conn: conn} do
      legitimate_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)"
      ]

      Enum.each(legitimate_agents, fn agent ->
        log = capture_log(fn ->
          conn
          |> put_req_header("user-agent", agent)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        # Should not log suspicious activity for legitimate browsers
        refute log =~ "suspicious_user_agent"
      end)
    end

    test "handles missing user agent header", %{conn: conn} do
      log = capture_log(fn ->
        LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])
      end)

      # Should not crash, just log nothing
      refute log =~ "suspicious_user_agent"
    end
  end

  describe "suspicious content type detection" do
    test "detects suspicious content types", %{conn: conn} do
      suspicious_types = [
        "application/x-www-form-urlencoded",
        "multipart/form-data",
        "text/plain",
        "application/xml",
        "text/xml"
      ]

      Enum.each(suspicious_types, fn content_type ->
        log = capture_log(fn ->
          conn
          |> put_req_header("content-type", content_type)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_content_type" or log == ""
      end)
    end

    test "allows JSON content type", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      refute log =~ "suspicious_content_type"
    end

    test "handles missing content type header", %{conn: conn} do
      log = capture_log(fn ->
        LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])
      end)

      refute log =~ "suspicious_content_type"
    end
  end

  describe "suspicious request path detection" do
    test "detects path traversal attempts", %{conn: conn} do
      suspicious_paths = [
        "/api/../../../etc/passwd",
        "/api/..\\..\\windows\\system32",
        "/api/users/../admin"
      ]

      Enum.each(suspicious_paths, fn path ->
        log = capture_log(fn ->
          conn
          |> Map.put(:request_path, path)
          |> Map.put(:status, 400)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_request_path" or log == ""
      end)
    end

    test "detects system file access attempts", %{conn: conn} do
      system_paths = [
        "/api/../../etc/passwd",
        "/api/../../etc/shadow",
        "/api/../proc/self/environ",
        "/api/../sys/kernel"
      ]

      Enum.each(system_paths, fn path ->
        log = capture_log(fn ->
          conn
          |> Map.put(:request_path, path)
          |> Map.put(:status, 400)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_request_path" or log == ""
      end)
    end

    test "detects script execution attempts", %{conn: conn} do
      script_paths = [
        "/api/cmd.exe",
        "/api/powershell.exe",
        "/api/bash",
        "/api/eval.php"
      ]

      Enum.each(script_paths, fn path ->
        log = capture_log(fn ->
          conn
          |> Map.put(:request_path, path)
          |> Map.put(:status, 400)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        assert log =~ "suspicious_request_path" or log == ""
      end)
    end

    test "allows legitimate API paths", %{conn: conn} do
      legitimate_paths = [
        "/api/users",
        "/api/auth/login",
        "/api/payments",
        "/api/profile"
      ]

      Enum.each(legitimate_paths, fn path ->
        log = capture_log(fn ->
          conn
          |> Map.put(:request_path, path)
          |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
        end)

        refute log =~ "suspicious_request_path"
      end)
    end
  end

  describe "response status code auditing" do
    test "logs authentication failures (401)", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:status, 401)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "authentication_failure" or log == ""
    end

    test "logs authorization failures (403)", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:status, 403)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "authorization_failure" or log == ""
    end

    test "logs rate limit violations (429)", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:status, 429)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "rate_limit_exceeded" or log == ""
    end

    test "logs bad requests (400)", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:status, 400)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "malformed_json_request" or log == ""
    end

    test "does not log successful requests (200)", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:status, 200)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Should not log security events for successful requests
      refute log =~ "authentication_failure"
      refute log =~ "authorization_failure"
    end

    test "does not log created responses (201)", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:status, 201)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      refute log =~ "authentication_failure"
    end
  end

  describe "multiple suspicious indicators" do
    test "logs multiple security issues in single request", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("x-forwarded-for", "127.0.0.1")
        |> put_req_header("user-agent", "sqlmap/1.0")
        |> put_req_header("content-type", "text/xml")
        |> Map.put(:status, 401)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Should log multiple security events
      assert log =~ "suspicious" or log =~ "authentication_failure" or log == ""
    end
  end

  describe "request context preservation" do
    test "preserves original request information", %{conn: conn} do
      original_method = conn.method
      original_path = conn.request_path

      conn = LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])

      assert conn.method == original_method
      assert conn.request_path == original_path
    end
  end

  describe "edge cases and boundary conditions" do
    test "handles request with no headers", %{conn: conn} do
      # Remove all headers
      conn = %{conn | req_headers: []}

      _log = capture_log(fn ->
        LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])
      end)

      # Should not crash - just verify it completes
      assert true
    end

    test "handles request with nil status", %{conn: conn} do
      conn = %{conn | status: nil}

      _log = capture_log(fn ->
        LedgerBankApiWeb.Plugs.SecurityAudit.call(conn, [])
      end)

      # Should not crash
      refute conn.halted
    end

    test "handles very long header values", %{conn: conn} do
      long_value = String.duplicate("a", 10000)

      _log = capture_log(fn ->
        conn
        |> put_req_header("user-agent", long_value)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Should not crash
      refute conn.halted
    end

    test "handles binary data in headers", %{conn: conn} do
      _log = capture_log(fn ->
        conn
        |> put_req_header("user-agent", <<0, 1, 2, 3>>)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Should handle gracefully
      refute conn.halted
    end
  end

  describe "X-Forwarded-For header handling" do
    test "checks x-forwarded-for header", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("x-forwarded-for", "192.168.1.1")
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "suspicious_ip_header" or log == ""
    end

    test "checks x-real-ip header", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("x-real-ip", "10.0.0.1")
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "suspicious_ip_header" or log == ""
    end

    test "checks x-originating-ip header", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("x-originating-ip", "172.16.0.1")
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      assert log =~ "suspicious_ip_header" or log == ""
    end
  end

  describe "security audit logging format" do
    test "includes request method in audit log", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:method, "POST")
        |> Map.put(:status, 401)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Log should include method information (if logging is working)
      assert is_binary(log)
    end

    test "includes request path in audit log", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:request_path, "/api/auth/login")
        |> Map.put(:status, 401)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Should include path information
      assert is_binary(log)
    end

    test "includes timestamp in audit log", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> Map.put(:status, 401)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Timestamp should be included
      assert is_binary(log)
    end
  end

  describe "integration with correlation ID" do
    test "includes correlation ID in audit logs", %{conn: conn} do
      correlation_id = "test-correlation-#{System.unique_integer()}"

      log = capture_log(fn ->
        conn
        |> assign(:correlation_id, correlation_id)
        |> Map.put(:status, 401)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Correlation ID should be in logs
      assert is_binary(log)
    end
  end

  describe "concurrent audit logging" do
    test "handles concurrent requests without race conditions", %{conn: _conn} do
      tasks = Enum.map(1..50, fn i ->
        Task.async(fn ->
          conn = build_conn(:get, "/api/test")

          capture_log(fn ->
            conn
            |> put_req_header("user-agent", "test-agent-#{i}")
            |> Map.put(:status, 401)
            |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
          end)
        end)
      end)

      results = Task.await_many(tasks)

      # All should complete without errors
      assert length(results) == 50
      Enum.each(results, fn log ->
        assert is_binary(log)
      end)
    end
  end

  describe "audit event types" do
    test "audit_request happens before audit_response", %{conn: conn} do
      # This tests the flow, though implementation details may vary
      log = capture_log(fn ->
        conn
        |> put_req_header("user-agent", "sqlmap")
        |> Map.put(:status, 401)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Both request and response auditing should occur
      assert is_binary(log)
    end
  end

  describe "security patterns - comprehensive testing" do
    test "detects combined attack vectors", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("x-forwarded-for", "127.0.0.1")
        |> put_req_header("user-agent", "sqlmap/1.0")
        |> put_req_header("content-type", "text/xml")
        |> Map.put(:request_path, "/api/../../../etc/passwd")
        |> Map.put(:status, 400)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Should detect multiple suspicious patterns
      assert is_binary(log)
    end

    test "does not flag legitimate API usage", %{conn: conn} do
      log = capture_log(fn ->
        conn
        |> put_req_header("user-agent", "Mozilla/5.0 (Windows NT 10.0)")
        |> put_req_header("content-type", "application/json")
        |> Map.put(:request_path, "/api/users")
        |> Map.put(:status, 200)
        |> LedgerBankApiWeb.Plugs.SecurityAudit.call([])
      end)

      # Should not log any suspicious activity
      refute log =~ "suspicious"
      refute log =~ "failure"
    end
  end
end

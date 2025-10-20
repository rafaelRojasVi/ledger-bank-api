defmodule LedgerBankApiWeb.Plugs.SecurityHeadersTest do
  use LedgerBankApiWeb.ConnCase, async: true

  alias LedgerBankApiWeb.Plugs.SecurityHeaders

  describe "security headers" do
    test "adds security headers to responses" do
      conn =
        build_conn()
        |> SecurityHeaders.call(SecurityHeaders.init([]))

      # Check security headers
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "x-xss-protection") == ["1; mode=block"]
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]

      assert get_resp_header(conn, "permissions-policy") == [
               "geolocation=(), microphone=(), camera=()"
             ]

      # Check CSP header
      csp = get_resp_header(conn, "content-security-policy") |> List.first()
      assert String.contains?(csp, "default-src 'none'")
      assert String.contains?(csp, "script-src 'none'")
      assert String.contains?(csp, "frame-ancestors 'none'")

      # Check CORS headers
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]

      assert get_resp_header(conn, "access-control-allow-methods") == [
               "GET, POST, PUT, DELETE, OPTIONS"
             ]

      assert get_resp_header(conn, "access-control-allow-headers") == [
               "Content-Type, Authorization, X-Correlation-ID"
             ]

      assert get_resp_header(conn, "access-control-max-age") == ["86400"]
    end

    test "does not add HSTS header in development" do
      conn =
        build_conn()
        |> SecurityHeaders.call(SecurityHeaders.init([]))

      # HSTS should not be present in development
      assert get_resp_header(conn, "strict-transport-security") == []
    end
  end
end

defmodule LedgerBankApiWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Security headers plug for enhancing API security.

  Adds comprehensive security headers to all responses including:
  - Content Security Policy (CSP)
  - X-Frame-Options
  - X-Content-Type-Options
  - X-XSS-Protection
  - Strict-Transport-Security (HSTS)
  - Referrer-Policy
  - Permissions-Policy
  """

  import Plug.Conn
  require Logger

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_security_headers()
    |> put_cors_headers()
  end

  defp put_security_headers(conn) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_csp_header()
    |> put_hsts_header()
  end

  defp put_csp_header(conn) do
    # Content Security Policy for API endpoints
    csp = "default-src 'none'; " <>
          "script-src 'none'; " <>
          "style-src 'none'; " <>
          "img-src 'none'; " <>
          "font-src 'none'; " <>
          "connect-src 'self'; " <>
          "frame-ancestors 'none'; " <>
          "base-uri 'none'; " <>
          "form-action 'none'"

    put_resp_header(conn, "content-security-policy", csp)
  end

  defp put_hsts_header(conn) do
    # Only add HSTS in production with HTTPS
    if Application.get_env(:ledger_bank_api, :environment) == :prod do
      hsts = "max-age=31536000; includeSubDomains; preload"
      put_resp_header(conn, "strict-transport-security", hsts)
    else
      conn
    end
  end

  defp put_cors_headers(conn) do
    # CORS headers for API access
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, X-Correlation-ID")
    |> put_resp_header("access-control-max-age", "86400")
  end
end

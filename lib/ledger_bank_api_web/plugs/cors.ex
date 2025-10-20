defmodule LedgerBankApiWeb.Plugs.Cors do
  @moduledoc """
  CORS (Cross-Origin Resource Sharing) plug for API endpoints.

  Handles preflight OPTIONS requests and adds appropriate CORS headers
  to allow cross-origin requests from web applications.
  """

  import Plug.Conn
  require Logger

  @allowed_origins [
    # React development server
    "http://localhost:3000",
    # Alternative frontend port
    "http://localhost:3001",
    # Vite development server
    "http://localhost:5173",
    # Vue development server
    "http://localhost:8080",
    # Production frontend
    "https://ledgerbank.com",
    "https://www.ledgerbank.com"
  ]

  @allowed_methods ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
  @allowed_headers [
    "accept",
    "accept-encoding",
    "authorization",
    "content-type",
    "x-correlation-id",
    "x-api-version",
    "x-requested-with"
  ]

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = get_req_header(conn, "origin") |> List.first()

    conn
    |> put_cors_headers(origin)
    |> handle_preflight()
  end

  defp put_cors_headers(conn, origin) do
    allowed_origin = if origin in @allowed_origins, do: origin, else: "*"

    conn
    |> put_resp_header("access-control-allow-origin", allowed_origin)
    |> put_resp_header("access-control-allow-methods", Enum.join(@allowed_methods, ", "))
    |> put_resp_header("access-control-allow-headers", Enum.join(@allowed_headers, ", "))
    |> put_resp_header("access-control-max-age", "86400")
    |> put_resp_header("access-control-allow-credentials", "true")
  end

  defp handle_preflight(conn) do
    if conn.method == "OPTIONS" do
      conn
      |> put_status(200)
      |> halt()
    else
      conn
    end
  end
end

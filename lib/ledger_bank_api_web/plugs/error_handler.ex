defmodule LedgerBankApiWeb.Plugs.ErrorHandler do
  @moduledoc """
  Global error handling plug.
  Catches and formats any unhandled errors in the request pipeline.
  """

  import Plug.Conn
  import Phoenix.Controller

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, &handle_errors/1)
  end

  defp handle_errors(%{status: status} = conn) when status >= 400 do
    # Error already handled by controller
    conn
  end

  defp handle_errors(conn) do
    conn
  end

  def handle_error(conn, error) do
    Logger.error("Unhandled error in request", %{
      error: inspect(error),
      path: conn.request_path,
      method: conn.method,
      remote_ip: format_ip(conn.remote_ip)
    })

    conn
    |> put_status(500)
    |> json(%{
      error: %{
        type: :internal_server_error,
        message: "An unexpected error occurred",
        code: 500
      }
    })
  end

  defp format_ip(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end
end

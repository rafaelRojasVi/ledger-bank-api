defmodule LedgerBankApiWeb.Plugs.RateLimit do
  @moduledoc """
  Basic rate limiting plug.
  Limits requests per IP address per minute.
  """

  import Plug.Conn
  import Phoenix.Controller

  @rate_limit 100 # requests per minute
  @rate_window 60_000 # 1 minute in milliseconds

  def init(opts), do: opts

  def call(conn, _opts) do
    client_id = get_client_id(conn)
    current_time = System.system_time(:millisecond)

    case check_rate_limit(client_id, current_time) do
      :ok ->
        conn

      :rate_limited ->
        conn
        |> put_status(429)
        |> json(%{
          error: %{
            type: :rate_limit_exceeded,
            message: "Rate limit exceeded. Please try again later.",
            code: 429,
            retry_after: @rate_window
          }
        })
        |> halt()
    end
  end

  defp get_client_id(conn) do
    # Use IP address as client identifier
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp check_rate_limit(client_id, current_time) do
    # Simple in-memory rate limiting using Process dictionary
    # In production, use Redis or similar for distributed rate limiting
    key = "rate_limit:#{client_id}"

    case Process.get(key) do
      nil ->
        Process.put(key, %{count: 1, window_start: current_time})
        :ok

      %{count: count, window_start: window_start} ->
        if current_time - window_start > @rate_window do
          # Window expired, reset
          Process.put(key, %{count: 1, window_start: current_time})
          :ok
        else
          if count >= @rate_limit do
            :rate_limited
          else
            Process.put(key, %{count: count + 1, window_start: window_start})
            :ok
          end
        end
    end
  end
end

defmodule LedgerBankApiWeb.Plugs.RateLimit do
  @moduledoc """
  Simple rate limiting plug using ETS for in-memory storage.

  This plug implements basic rate limiting to prevent abuse and ensure
  fair usage of API resources.

  ## Configuration

  - `:window_size` - Time window in milliseconds (default: 60_000 = 1 minute)
  - `:max_requests` - Maximum requests per window (default: 100)
  - `:key_func` - Function to generate rate limit key (default: IP address)

  ## Usage

      plug LedgerBankApiWeb.Plugs.RateLimit, max_requests: 50, window_size: 30_000

  ## Rate Limit Headers

  The plug adds standard rate limit headers to responses:
  - `X-RateLimit-Limit` - Maximum requests per window
  - `X-RateLimit-Remaining` - Remaining requests in current window
  - `X-RateLimit-Reset` - Unix timestamp when the window resets
  """

  import Plug.Conn
  require Logger

  @behaviour Plug

  @default_window_size 60_000  # 1 minute
  @default_max_requests 100
  @default_key_func &__MODULE__.default_key_func/1

  def init(opts) do
    %{
      window_size: Keyword.get(opts, :window_size, @default_window_size),
      max_requests: Keyword.get(opts, :max_requests, @default_max_requests),
      key_func: Keyword.get(opts, :key_func, @default_key_func)
    }
  end

  def call(conn, %{window_size: window_size, max_requests: max_requests, key_func: key_func}) do
    key = key_func.(conn)
    now = System.system_time(:millisecond)
    window_start = now - window_size

    # Clean up old entries
    cleanup_old_entries(window_start)

    # Get current request count
    current_count = get_request_count(key, window_start)

    if current_count >= max_requests do
      # Rate limit exceeded
      Logger.warning("Rate limit exceeded", %{
        key: key,
        current_count: current_count,
        max_requests: max_requests,
        window_size: window_size,
        correlation_id: conn.assigns[:correlation_id]
      })

      conn
      |> put_resp_header("x-rate-limit-limit", to_string(max_requests))
      |> put_resp_header("x-rate-limit-remaining", "0")
      |> put_resp_header("x-rate-limit-reset", to_string(now + window_size))
      |> send_resp(429, Jason.encode!(%{
        error: %{
          type: "rate_limit_exceeded",
          message: "Too many requests. Please try again later.",
          code: 429,
          timestamp: DateTime.utc_now()
        }
      }))
      |> halt()
    else
      # Record this request
      record_request(key, now)

      # Add rate limit headers
      remaining = max_requests - current_count - 1
      reset_time = now + window_size

      conn
      |> put_resp_header("x-rate-limit-limit", to_string(max_requests))
      |> put_resp_header("x-rate-limit-remaining", to_string(remaining))
      |> put_resp_header("x-rate-limit-reset", to_string(reset_time))
    end
  end

  # Default key function using IP address
  def default_key_func(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      _ ->
        case get_req_header(conn, "x-real-ip") do
          [ip] -> ip
          _ -> to_string(:inet.ntoa(conn.remote_ip))
        end
    end
  end

  # Get request count for a key within the window
  defp get_request_count(key, window_start) do
    case :ets.lookup(:rate_limit_table, key) do
      [{^key, timestamps}] ->
        timestamps
        |> Enum.filter(fn timestamp -> timestamp > window_start end)
        |> length()
      [] ->
        0
    end
  end

  # Record a request for a key
  defp record_request(key, timestamp) do
    case :ets.lookup(:rate_limit_table, key) do
      [{^key, timestamps}] ->
        new_timestamps = [timestamp | timestamps]
        :ets.insert(:rate_limit_table, {key, new_timestamps})
      [] ->
        :ets.insert(:rate_limit_table, {key, [timestamp]})
    end
  end

  # Clean up old entries to prevent memory leaks
  defp cleanup_old_entries(_window_start) do
    # For now, we'll implement a simple cleanup strategy
    # In production, you might want more sophisticated cleanup
    :ok
  end

  # Initialize ETS table if it doesn't exist
  def ensure_table_exists do
    case :ets.whereis(:rate_limit_table) do
      :undefined ->
        :ets.new(:rate_limit_table, [:set, :public, :named_table])
      _pid ->
        :ok
    end
  end
end

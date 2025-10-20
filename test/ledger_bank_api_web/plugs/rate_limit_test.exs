defmodule LedgerBankApiWeb.Plugs.RateLimitTest do
  use LedgerBankApiWeb.ConnCase, async: true

  alias LedgerBankApiWeb.Plugs.RateLimit

  setup do
    # Ensure the rate limit table exists
    RateLimit.ensure_table_exists()
    :ok
  end

  describe "rate limiting" do
    test "allows requests within limit" do
      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", "192.168.1.1")

      # First request should be allowed
      result_conn = RateLimit.call(conn, RateLimit.init(max_requests: 2, window_size: 60_000))

      refute result_conn.halted
      assert get_resp_header(result_conn, "x-rate-limit-limit") == ["2"]
      assert get_resp_header(result_conn, "x-rate-limit-remaining") == ["1"]
    end

    test "blocks requests when limit exceeded" do
      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", "192.168.1.2")

      # Make requests up to the limit
      for _i <- 1..2 do
        RateLimit.call(conn, RateLimit.init(max_requests: 2, window_size: 60_000))
      end

      # This request should be blocked
      result_conn = RateLimit.call(conn, RateLimit.init(max_requests: 2, window_size: 60_000))

      assert result_conn.halted
      assert result_conn.status == 429
      assert get_resp_header(result_conn, "x-rate-limit-remaining") == ["0"]
    end

    test "uses IP address as default key" do
      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", "192.168.1.3")

      result_conn = RateLimit.call(conn, RateLimit.init(max_requests: 1, window_size: 60_000))

      refute result_conn.halted
      assert get_resp_header(result_conn, "x-rate-limit-limit") == ["1"]
    end

    test "includes proper rate limit headers" do
      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", "192.168.1.4")

      result_conn = RateLimit.call(conn, RateLimit.init(max_requests: 5, window_size: 60_000))

      assert get_resp_header(result_conn, "x-rate-limit-limit") == ["5"]
      assert get_resp_header(result_conn, "x-rate-limit-remaining") == ["4"]
      assert get_resp_header(result_conn, "x-rate-limit-reset")
    end
  end
end

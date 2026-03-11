defmodule LedgerBankApi.Core.CircuitBreakerTest do
  @moduledoc """
  Tests for CircuitBreaker: success must not melt, failures must open the circuit,
  fallback when open, and reset closes the circuit.
  """
  use ExUnit.Case, async: true

  alias LedgerBankApi.Core.CircuitBreaker

  defp make_fuse_name do
    :"cb_test_#{System.unique_integer([:positive])}"
  end

  defp init_fuse(name, opts \\ []) do
    default = [max_failures: 2, timeout: 60_000, reset_timeout: 30_000]
    CircuitBreaker.init(name, Keyword.merge(default, opts))
  end

  describe "successful calls do not open the circuit" do
    test "many successes leave circuit closed" do
      name = make_fuse_name()
      assert :ok == init_fuse(name)

      for _ <- 1..5 do
        assert {:ok, :ok} == CircuitBreaker.call(name, fn -> :ok end)
      end

      assert {:ok, :closed} == CircuitBreaker.status(name)
    end
  end

  describe "repeated failures open the circuit" do
    test "after max_failures+1 failures, call returns circuit_breaker_open" do
      # Fuse blows when melts exceed max_failures (tolerates max_failures, then (max_failures+1)th melts)
      name = make_fuse_name()
      assert :ok == init_fuse(name, max_failures: 2)

      assert {:error, _} = CircuitBreaker.call(name, fn -> raise "fail" end)
      assert {:error, _} = CircuitBreaker.call(name, fn -> raise "fail" end)
      assert {:error, _} = CircuitBreaker.call(name, fn -> raise "fail" end)

      assert {:error, :circuit_breaker_open} ==
               CircuitBreaker.call(name, fn -> {:ok, :should_not_run} end)

      assert {:ok, :open} == CircuitBreaker.status(name)
    end
  end

  describe "call_with_fallback returns fallback when circuit is open" do
    test "fallback is used and returns its result" do
      name = make_fuse_name()
      assert :ok == init_fuse(name, max_failures: 2)

      Enum.each(1..3, fn _ ->
        CircuitBreaker.call(name, fn -> raise "no" end)
      end)

      assert {:ok, :fallback} ==
               CircuitBreaker.call_with_fallback(
                 name,
                 fn -> raise "no" end,
                 fn -> {:ok, :fallback} end
               )
    end
  end

  describe "reset closes the circuit" do
    test "after reset, call runs again and succeeds" do
      name = make_fuse_name()
      assert :ok == init_fuse(name, max_failures: 2)

      Enum.each(1..3, fn _ ->
        CircuitBreaker.call(name, fn -> raise "fail" end)
      end)

      assert {:ok, :open} == CircuitBreaker.status(name)
      assert :ok == CircuitBreaker.reset(name)
      assert {:ok, :closed} == CircuitBreaker.status(name)

      assert {:ok, :done} == CircuitBreaker.call(name, fn -> :done end)
    end
  end
end

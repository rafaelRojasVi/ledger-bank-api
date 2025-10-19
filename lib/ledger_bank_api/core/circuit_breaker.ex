defmodule LedgerBankApi.Core.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for external API calls.

  Provides resilience patterns to prevent cascading failures when external
  services are down or experiencing issues.

  Uses the Fuse library for circuit breaker functionality.
  """

  require Logger

  @doc """
  Execute a function with circuit breaker protection.

  ## Examples

      CircuitBreaker.call(:bank_api, fn ->
        ExternalBankAPI.get_accounts()
      end)

  """
  def call(fuse_name, fun, options \\ []) do
    timeout = Keyword.get(options, :timeout, 30_000)

    case :fuse.ask(fuse_name, :sync) do
      :ok ->
        execute_with_circuit_breaker(fuse_name, fun, timeout)

      :blown ->
        Logger.warning("Circuit breaker #{fuse_name} is blown, rejecting request")
        {:error, :circuit_breaker_open}

      {:error, :fuse_not_found} ->
        Logger.warning("Circuit breaker #{fuse_name} not found, executing without protection")
        execute_with_fallback(fun, timeout)
    end
  end

  @doc """
  Execute a function with circuit breaker protection and fallback.

  ## Examples

      CircuitBreaker.call_with_fallback(:bank_api,
        fn -> ExternalBankAPI.get_accounts() end,
        fn -> {:ok, []} end
      )

  """
  def call_with_fallback(fuse_name, fun, fallback_fun, options \\ []) do
    case call(fuse_name, fun, options) do
      {:ok, result} ->
        {:ok, result}

      {:error, :circuit_breaker_open} ->
        Logger.info("Circuit breaker #{fuse_name} is open, using fallback")
        fallback_fun.()

      {:error, reason} ->
        Logger.warning("Circuit breaker #{fuse_name} failed with #{inspect(reason)}, using fallback")
        fallback_fun.()
    end
  end

  @doc """
  Initialize a circuit breaker with specified configuration.

  ## Examples

      CircuitBreaker.init(:bank_api,
        max_failures: 5,
        timeout: 60_000,
        reset_timeout: 30_000
      )

  """
  def init(fuse_name, options \\ []) do
    max_failures = Keyword.get(options, :max_failures, 5)
    _timeout = Keyword.get(options, :timeout, 60_000)
    reset_timeout = Keyword.get(options, :reset_timeout, 30_000)

    fuse_options = [
      {:standard_fuse, max_failures, reset_timeout}
    ]

    case :fuse.install(fuse_name, fuse_options) do
      :ok ->
        Logger.info("Circuit breaker #{fuse_name} initialized with max_failures=#{max_failures}, reset_timeout=#{reset_timeout}ms")
        :ok

      {:error, reason} ->
        Logger.error("Failed to initialize circuit breaker #{fuse_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Check if a circuit breaker is available (not blown).
  """
  def available?(fuse_name) do
    case :fuse.ask(fuse_name, :sync) do
      :ok -> true
      :blown -> false
      {:error, :fuse_not_found} -> false
    end
  end

  @doc """
  Get circuit breaker status information.
  """
  def status(fuse_name) do
    case :fuse.ask(fuse_name, :sync) do
      :ok ->
        {:ok, :closed}

      :blown ->
        {:ok, :open}

      {:error, :fuse_not_found} ->
        {:error, :not_initialized}
    end
  end

  @doc """
  Manually reset a circuit breaker.
  """
  def reset(fuse_name) do
    case :fuse.reset(fuse_name) do
      :ok ->
        Logger.info("Circuit breaker #{fuse_name} manually reset")
        :ok

      {:error, reason} ->
        Logger.error("Failed to reset circuit breaker #{fuse_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Initialize default circuit breakers for the application.
  """
  def init_default_breakers do
    breakers = [
      {:bank_api, [max_failures: 5, timeout: 60_000, reset_timeout: 30_000]},
      {:payment_processor, [max_failures: 3, timeout: 45_000, reset_timeout: 60_000]},
      {:notification_service, [max_failures: 10, timeout: 30_000, reset_timeout: 15_000]}
    ]

    results = Enum.map(breakers, fn {name, options} ->
      init(name, options)
    end)

    failed = Enum.filter(results, fn
      :ok -> false
      _ -> true
    end)

    if length(failed) > 0 do
      Logger.error("Failed to initialize #{length(failed)} circuit breakers")
      {:error, failed}
    else
      Logger.info("Successfully initialized #{length(breakers)} circuit breakers")
      :ok
    end
  end

  # Private helper functions

  defp execute_with_circuit_breaker(fuse_name, fun, _timeout) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      duration = System.monotonic_time(:millisecond) - start_time

      # Report success to circuit breaker
      :fuse.melt(fuse_name)

      Logger.debug("Circuit breaker #{fuse_name} call succeeded in #{duration}ms")
      {:ok, result}

    rescue
      error ->
        duration = System.monotonic_time(:millisecond) - start_time

        # Report failure to circuit breaker
        :fuse.melt(fuse_name)

        Logger.warning("Circuit breaker #{fuse_name} call failed after #{duration}ms: #{inspect(error)}")
        {:error, error}

    catch
      :exit, reason ->
        duration = System.monotonic_time(:millisecond) - start_time

        # Report failure to circuit breaker
        :fuse.melt(fuse_name)

        Logger.warning("Circuit breaker #{fuse_name} call exited after #{duration}ms: #{inspect(reason)}")
        {:error, {:exit, reason}}

      kind, reason ->
        duration = System.monotonic_time(:millisecond) - start_time

        # Report failure to circuit breaker
        :fuse.melt(fuse_name)

        Logger.warning("Circuit breaker #{fuse_name} call threw #{kind} after #{duration}ms: #{inspect(reason)}")
        {:error, {kind, reason}}
    end
  end

  defp execute_with_fallback(fun, _timeout) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      duration = System.monotonic_time(:millisecond) - start_time

      Logger.debug("Fallback call succeeded in #{duration}ms")
      {:ok, result}

    rescue
      error ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.warning("Fallback call failed after #{duration}ms: #{inspect(error)}")
        {:error, error}

    catch
      :exit, reason ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.warning("Fallback call exited after #{duration}ms: #{inspect(reason)}")
        {:error, {:exit, reason}}

      kind, reason ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.warning("Fallback call threw #{kind} after #{duration}ms: #{inspect(reason)}")
        {:error, {kind, reason}}
    end
  end
end

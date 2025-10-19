defmodule LedgerBankApi.Core.Cache do
  @moduledoc """
  Caching module for frequently accessed data.

  Uses adapter pattern for pluggable cache backends (ETS, Redis, etc.).
  Delegates all operations to the configured adapter.

  ## Usage

      # Cache a value with TTL
      Cache.put("user:123", user_data, ttl: 300)

      # Get a cached value
      Cache.get("user:123")

      # Delete a cached value
      Cache.delete("user:123")

      # Clear all cache
      Cache.clear()

      # Get cache statistics
      Cache.stats()

  ## Configuration

      # config/config.exs (default)
      config :ledger_bank_api, :cache_adapter,
        LedgerBankApi.Core.Cache.EtsAdapter

      # config/prod.exs (future - for multi-node)
      config :ledger_bank_api, :cache_adapter,
        LedgerBankApi.Core.Cache.RedisAdapter

  ## Switching Adapters

  Change configuration and restart - no code changes needed!
  All adapters implement the same CacheAdapter behaviour.
  """

  alias LedgerBankApi.Core.CacheAdapter

  @adapter_module CacheAdapter.adapter()

  @doc """
  Initialize the cache backend.

  Delegates to the configured adapter.
  """
  def init do
    adapter().init()
  end

  @doc """
  Get a value from the cache.

  Delegates to the configured adapter.
  """
  def get(key) do
    adapter().get(key)
  end

  @doc """
  Put a value in the cache with optional TTL.

  Delegates to the configured adapter.
  """
  def put(key, value, opts \\ []) do
    adapter().put(key, value, opts)
  end

  @doc """
  Get a value from the cache or compute it if not found.

  Delegates to the configured adapter.
  """
  def get_or_put(key, fun, opts \\ []) when is_function(fun, 0) do
    adapter().get_or_put(key, fun, opts)
  end

  @doc """
  Delete a value from the cache.

  Delegates to the configured adapter.
  """
  def delete(key) do
    adapter().delete(key)
  end

  @doc """
  Clear all cache entries.

  Delegates to the configured adapter.
  """
  def clear do
    adapter().clear()
  end

  @doc """
  Get cache statistics.

  Delegates to the configured adapter.
  """
  def stats do
    adapter().stats()
  end

  @doc """
  Clean up expired entries from the cache.

  Delegates to the configured adapter.
  """
  def cleanup do
    adapter().cleanup()
  end

  @doc """
  Get cache entry details for debugging.

  Delegates to the configured adapter.
  """
  def get_entry_details(key) do
    adapter().get_entry_details(key)
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp adapter do
    @adapter_module
  end
end

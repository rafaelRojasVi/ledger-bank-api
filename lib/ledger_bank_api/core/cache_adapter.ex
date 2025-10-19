defmodule LedgerBankApi.Core.CacheAdapter do
  @moduledoc """
  Behaviour for cache implementations.

  Enables switching between different cache backends (ETS, Redis, Memcached)
  without changing application code.

  ## Philosophy

  - **Adapter pattern** - Swap implementations via configuration
  - **Same interface** - All adapters implement identical API
  - **Testing flexibility** - Mock adapter for tests
  - **Horizontal scaling** - Redis for distributed caching

  ## Configuration

      # config/config.exs
      config :ledger_bank_api, :cache_adapter,
        LedgerBankApi.Core.Cache.EtsAdapter  # Default

      # config/prod.exs (future)
      config :ledger_bank_api, :cache_adapter,
        LedgerBankApi.Core.Cache.RedisAdapter

  ## Implementing an Adapter

      defmodule MyApp.Cache.RedisAdapter do
        @behaviour LedgerBankApi.Core.CacheAdapter

        @impl true
        def init, do: # Connect to Redis

        @impl true
        def get(key), do: # Redis GET

        @impl true
        def put(key, value, opts), do: # Redis SET with TTL

        # ... implement all callbacks
      end

  ## Usage (Application Code - No Changes Needed)

      Cache.get("user:123")       # Works with any adapter
      Cache.put("user:123", user) # Works with any adapter
  """

  @doc """
  Initialize the cache backend.

  Called once during application startup.
  """
  @callback init() :: :ok | {:error, term()}

  @doc """
  Get a value from the cache.

  Returns {:ok, value} if found and not expired.
  Returns :not_found if key doesn't exist or is expired.
  """
  @callback get(key :: String.t()) :: {:ok, term()} | :not_found

  @doc """
  Put a value in the cache with optional TTL.

  Options:
  - `:ttl` - Time to live in seconds (default: 300)

  Returns :ok on success.
  """
  @callback put(key :: String.t(), value :: term(), opts :: keyword()) :: :ok

  @doc """
  Get a value from cache or compute it if not found.

  The function should return {:ok, value} or {:error, reason}.
  """
  @callback get_or_put(key :: String.t(), fun :: (-> {:ok, term()} | {:error, term()}), opts :: keyword()) ::
    {:ok, term()} | {:error, term()}

  @doc """
  Delete a value from the cache.

  Returns :ok even if key doesn't exist.
  """
  @callback delete(key :: String.t()) :: :ok

  @doc """
  Clear all cache entries.

  Use with caution in production.
  """
  @callback clear() :: :ok

  @doc """
  Get cache statistics.

  Returns a map with adapter-specific statistics.
  Recommended keys:
  - `:total_entries` - Total number of cached entries
  - `:active_entries` - Non-expired entries
  - `:expired_entries` - Expired but not cleaned up
  - `:total_access_count` - Total number of cache hits
  - `:average_access_count` - Average accesses per entry
  """
  @callback stats() :: map()

  @doc """
  Clean up expired entries from the cache.

  Returns the number of entries removed.
  """
  @callback cleanup() :: non_neg_integer()

  @doc """
  Get detailed information about a cache entry (debugging).

  Returns nil if key doesn't exist.
  """
  @callback get_entry_details(key :: String.t()) :: map() | nil

  @doc """
  Get the configured cache adapter module.

  Defaults to EtsAdapter if not configured.
  """
  def adapter do
    Application.get_env(:ledger_bank_api, :cache_adapter,
      LedgerBankApi.Core.Cache.EtsAdapter)
  end
end


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

      # For multi-node deployments, implement a distributed cache adapter
      # config/prod.exs (future - for multi-node)
      # config :ledger_bank_api, :cache_adapter,
      #   LedgerBankApi.Core.Cache.DistributedAdapter

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
  # STANDARDIZED TTL HELPERS
  # ============================================================================

  @doc """
  Cache with short TTL (5 minutes) for frequently changing data.

  ## Examples

      # Cache user session data
      Cache.put_short("user:123:session", session_data)

      # Cache API rate limit data
      Cache.put_short("rate_limit:user:123", %{count: 10, reset_at: ~U[2024-01-01 12:00:00Z]})
  """
  def put_short(key, value) do
    put(key, value, ttl: 300) # 5 minutes
  end

  @doc """
  Cache with medium TTL (1 hour) for moderately stable data.

  ## Examples

      # Cache user profile data
      Cache.put_medium("user:123:profile", profile_data)

      # Cache bank account data
      Cache.put_medium("bank:account:123", account_data)
  """
  def put_medium(key, value) do
    put(key, value, ttl: 3600) # 1 hour
  end

  @doc """
  Cache with long TTL (24 hours) for stable data.

  ## Examples

      # Cache bank information
      Cache.put_long("bank:info:123", bank_data)

      # Cache configuration data
      Cache.put_long("config:app_settings", settings)
  """
  def put_long(key, value) do
    put(key, value, ttl: 86400) # 24 hours
  end

  @doc """
  Cache with very long TTL (7 days) for rarely changing data.

  ## Examples

      # Cache bank branch data
      Cache.put_very_long("bank:branches:123", branch_data)

      # Cache country/currency data
      Cache.put_very_long("currencies:list", currency_list)
  """
  def put_very_long(key, value) do
    put(key, value, ttl: 604800) # 7 days
  end

  @doc """
  Get or put with short TTL (5 minutes).

  ## Examples

      # Cache user session with short TTL
      session_data = Cache.get_or_put_short("user:123:session", fn ->
        UserService.get_session_data(user_id)
      end)
  """
  def get_or_put_short(key, fun) when is_function(fun, 0) do
    get_or_put(key, fun, ttl: 300) # 5 minutes
  end

  @doc """
  Get or put with medium TTL (1 hour).

  ## Examples

      # Cache user profile with medium TTL
      profile = Cache.get_or_put_medium("user:123:profile", fn ->
        UserService.get_profile(user_id)
      end)
  """
  def get_or_put_medium(key, fun) when is_function(fun, 0) do
    get_or_put(key, fun, ttl: 3600) # 1 hour
  end

  @doc """
  Get or put with long TTL (24 hours).

  ## Examples

      # Cache bank info with long TTL
      bank_info = Cache.get_or_put_long("bank:info:123", fn ->
        BankService.get_bank_info(bank_id)
      end)
  """
  def get_or_put_long(key, fun) when is_function(fun, 0) do
    get_or_put(key, fun, ttl: 86400) # 24 hours
  end

  @doc """
  Get or put with very long TTL (7 days).

  ## Examples

      # Cache bank branches with very long TTL
      branches = Cache.get_or_put_very_long("bank:branches:123", fn ->
        BankService.get_branches(bank_id)
      end)
  """
  def get_or_put_very_long(key, fun) when is_function(fun, 0) do
    get_or_put(key, fun, ttl: 604800) # 7 days
  end

  @doc """
  Cache with custom TTL using predefined constants.

  ## Examples

      # Cache with 30 minutes TTL
      Cache.put_with_ttl("user:123:temp", data, :thirty_minutes)

      # Cache with 2 hours TTL
      Cache.put_with_ttl("user:123:extended", data, :two_hours)
  """
  def put_with_ttl(key, value, ttl_constant) do
    ttl = ttl_seconds(ttl_constant)
    put(key, value, ttl: ttl)
  end

  @doc """
  Get or put with custom TTL using predefined constants.

  ## Examples

      # Cache with 30 minutes TTL
      data = Cache.get_or_put_with_ttl("user:123:temp", fn ->
        compute_expensive_data()
      end, :thirty_minutes)
  """
  def get_or_put_with_ttl(key, fun, ttl_constant) when is_function(fun, 0) do
    ttl = ttl_seconds(ttl_constant)
    get_or_put(key, fun, ttl: ttl)
  end

  @doc """
  Cache with TTL based on data type.

  ## Examples

      # Cache user data (medium TTL)
      Cache.put_by_type("user:123", user_data, :user)

      # Cache bank data (long TTL)
      Cache.put_by_type("bank:123", bank_data, :bank)

      # Cache session data (short TTL)
      Cache.put_by_type("session:123", session_data, :session)
  """
  def put_by_type(key, value, data_type) do
    ttl = ttl_by_type(data_type)
    put(key, value, ttl: ttl)
  end

  @doc """
  Get or put with TTL based on data type.

  ## Examples

      # Cache user data with appropriate TTL
      user_data = Cache.get_or_put_by_type("user:123", fn ->
        UserService.get_user(user_id)
      end, :user)
  """
  def get_or_put_by_type(key, fun, data_type) when is_function(fun, 0) do
    ttl = ttl_by_type(data_type)
    get_or_put(key, fun, ttl: ttl)
  end

  @doc """
  Cache with TTL based on data freshness requirements.

  ## Examples

      # Cache real-time data (very short TTL)
      Cache.put_by_freshness("realtime:balance:123", balance_data, :realtime)

      # Cache daily data (medium TTL)
      Cache.put_by_freshness("daily:stats:123", stats_data, :daily)
  """
  def put_by_freshness(key, value, freshness_level) do
    ttl = ttl_by_freshness(freshness_level)
    put(key, value, ttl: ttl)
  end

  @doc """
  Get or put with TTL based on data freshness requirements.

  ## Examples

      # Cache real-time data with appropriate TTL
      balance = Cache.get_or_put_by_freshness("realtime:balance:123", fn ->
        AccountService.get_balance(account_id)
      end, :realtime)
  """
  def get_or_put_by_freshness(key, fun, freshness_level) when is_function(fun, 0) do
    ttl = ttl_by_freshness(freshness_level)
    get_or_put(key, fun, ttl: ttl)
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp adapter do
    @adapter_module
  end

  # TTL constants in seconds
  defp ttl_seconds(:thirty_seconds), do: 30
  defp ttl_seconds(:one_minute), do: 60
  defp ttl_seconds(:five_minutes), do: 300
  defp ttl_seconds(:thirty_minutes), do: 1800
  defp ttl_seconds(:one_hour), do: 3600
  defp ttl_seconds(:two_hours), do: 7200
  defp ttl_seconds(:six_hours), do: 21600
  defp ttl_seconds(:twelve_hours), do: 43200
  defp ttl_seconds(:one_day), do: 86400
  defp ttl_seconds(:three_days), do: 259200
  defp ttl_seconds(:one_week), do: 604800
  defp ttl_seconds(:two_weeks), do: 1209600
  defp ttl_seconds(:one_month), do: 2592000
  defp ttl_seconds(_), do: 3600 # Default to 1 hour

  # TTL by data type
  defp ttl_by_type(:user), do: 3600 # 1 hour
  defp ttl_by_type(:bank), do: 86400 # 24 hours
  defp ttl_by_type(:session), do: 300 # 5 minutes
  defp ttl_by_type(:config), do: 604800 # 7 days
  defp ttl_by_type(:stats), do: 1800 # 30 minutes
  defp ttl_by_type(:rate_limit), do: 300 # 5 minutes
  defp ttl_by_type(:temp), do: 60 # 1 minute
  defp ttl_by_type(_), do: 3600 # Default to 1 hour

  # TTL by freshness level
  defp ttl_by_freshness(:realtime), do: 30 # 30 seconds
  defp ttl_by_freshness(:near_realtime), do: 300 # 5 minutes
  defp ttl_by_freshness(:hourly), do: 3600 # 1 hour
  defp ttl_by_freshness(:daily), do: 86400 # 24 hours
  defp ttl_by_freshness(:weekly), do: 604800 # 7 days
  defp ttl_by_freshness(:monthly), do: 2592000 # 30 days
  defp ttl_by_freshness(_), do: 3600 # Default to 1 hour
end

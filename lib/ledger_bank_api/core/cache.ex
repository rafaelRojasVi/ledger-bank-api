defmodule LedgerBankApi.Core.Cache do
  @moduledoc """
  Caching module for frequently accessed data.

  Provides a simple in-memory cache using ETS tables with TTL support.
  Includes cache invalidation, statistics, and performance monitoring.

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
  """

  require Logger
  alias LedgerBankApiWeb.Logger, as: AppLogger

  @cache_table :ledger_cache
  @default_ttl 300  # 5 minutes
  @max_ttl 3600    # 1 hour

  @doc """
  Initialize the cache table.
  """
  def init do
    case :ets.whereis(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:set, :public, :named_table])
        :ok
      _pid ->
        :ok
    end
  end

  @doc """
  Put a value in the cache with optional TTL.
  """
  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    ttl = min(ttl, @max_ttl)  # Cap TTL to prevent memory issues

    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)

    cache_entry = %{
      value: value,
      expires_at: expires_at,
      created_at: DateTime.utc_now(),
      access_count: 0
    }

    :ets.insert(@cache_table, {key, cache_entry})

    # Log cache operation
    AppLogger.log_business_event("cache_put", %{
      key: key,
      ttl: ttl,
      expires_at: expires_at
    })

    :ok
  end

  @doc """
  Get a value from the cache.
  """
  def get(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, cache_entry}] ->
        if DateTime.compare(DateTime.utc_now(), cache_entry.expires_at) == :lt do
          # Update access count
          updated_entry = %{cache_entry | access_count: cache_entry.access_count + 1}
          :ets.insert(@cache_table, {key, updated_entry})

          # Log cache hit
          AppLogger.log_business_event("cache_hit", %{
            key: key,
            access_count: updated_entry.access_count
          })

          {:ok, cache_entry.value}
        else
          # Expired, remove from cache
          :ets.delete(@cache_table, key)

          # Log cache miss (expired)
          AppLogger.log_business_event("cache_miss_expired", %{
            key: key,
            expires_at: cache_entry.expires_at
          })

          :not_found
        end
      [] ->
        # Log cache miss (not found)
        AppLogger.log_business_event("cache_miss_not_found", %{
          key: key
        })

        :not_found
    end
  end

  @doc """
  Get a value from the cache or compute it if not found.
  """
  def get_or_put(key, fun, opts \\ []) when is_function(fun, 0) do
    case get(key) do
      {:ok, value} ->
        {:ok, value}
      :not_found ->
        # Compute the value
        case fun.() do
          {:ok, value} ->
            put(key, value, opts)
            {:ok, value}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Delete a value from the cache.
  """
  def delete(key) do
    :ets.delete(@cache_table, key)

    # Log cache deletion
    AppLogger.log_business_event("cache_delete", %{
      key: key
    })

    :ok
  end

  @doc """
  Clear all cache entries.
  """
  def clear do
    :ets.delete_all_objects(@cache_table)

    # Log cache clear
    AppLogger.log_business_event("cache_clear", %{})

    :ok
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    entries = :ets.tab2list(@cache_table)
    now = DateTime.utc_now()

    {active_entries, expired_entries} = Enum.split_with(entries, fn {_key, entry} ->
      DateTime.compare(now, entry.expires_at) == :lt
    end)

    total_access_count = Enum.reduce(active_entries, 0, fn {_key, entry}, acc ->
      acc + entry.access_count
    end)

    stats = %{
      total_entries: length(entries),
      active_entries: length(active_entries),
      expired_entries: length(expired_entries),
      total_access_count: total_access_count,
      average_access_count: if length(active_entries) > 0 do
        total_access_count / length(active_entries)
      else
        0
      end
    }

    # Log cache statistics
    AppLogger.log_business_event("cache_stats", stats)

    stats
  end

  @doc """
  Clean up expired entries from the cache.
  """
  def cleanup do
    now = DateTime.utc_now()
    entries = :ets.tab2list(@cache_table)

    expired_keys = entries
    |> Enum.filter(fn {_key, entry} ->
      DateTime.compare(now, entry.expires_at) != :lt
    end)
    |> Enum.map(fn {key, _entry} -> key end)

    Enum.each(expired_keys, &delete/1)

    # Log cleanup
    AppLogger.log_business_event("cache_cleanup", %{
      expired_entries_removed: length(expired_keys)
    })

    length(expired_keys)
  end

  @doc """
  Get cache entry details for debugging.
  """
  def get_entry_details(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, cache_entry}] ->
        now = DateTime.utc_now()
        is_expired = DateTime.compare(now, cache_entry.expires_at) != :lt

        %{
          key: key,
          value: cache_entry.value,
          created_at: cache_entry.created_at,
          expires_at: cache_entry.expires_at,
          access_count: cache_entry.access_count,
          is_expired: is_expired,
          ttl_remaining: if is_expired do
            0
          else
            DateTime.diff(cache_entry.expires_at, now, :second)
          end
        }
      [] ->
        nil
    end
  end
end

defmodule LedgerBankApi.Cache do
  @moduledoc """
  Enhanced caching module for frequently accessed data with comprehensive error handling.
  Provides TTL-based caching with automatic invalidation and standardized return patterns.
  All functions return {:ok, data} or {:error, reason} for consistency.
  """

  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  @cache_ttl 300 # 5 minutes default TTL

  @doc """
  Gets a value from cache with standardized return pattern.
  Returns {:ok, value} or {:error, :not_found}.
  """
  def get(key) do
    context = %{action: :cache_get, key: key}

    ErrorHandler.with_error_handling(fn ->
      case :ets.lookup(:ledger_cache, key) do
        [{^key, value, expires_at}] ->
          if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
            {:ok, value}
          else
            :ets.delete(:ledger_cache, key)
            {:error, :not_found}
          end
        [] ->
          {:error, :not_found}
      end
    end, context)
  end

  @doc """
  Sets a value in cache with TTL and standardized return pattern.
  Returns {:ok, value} or {:error, reason}.
  """
  def set(key, value, ttl \\ @cache_ttl) do
    context = %{action: :cache_set, key: key, ttl: ttl}

    ErrorHandler.with_error_handling(fn ->
      expires_at = DateTime.utc_now() |> DateTime.add(ttl, :second)
      :ets.insert(:ledger_cache, {key, value, expires_at})
      {:ok, value}
    end, context)
  end

  @doc """
  Deletes a value from cache with standardized return pattern.
  Returns {:ok, :deleted} or {:error, reason}.
  """
  def delete(key) do
    context = %{action: :cache_delete, key: key}

    ErrorHandler.with_error_handling(fn ->
      :ets.delete(:ledger_cache, key)
      {:ok, :deleted}
    end, context)
  end

  @doc """
  Invalidates cache by pattern with standardized return pattern.
  Returns {:ok, deleted_count} or {:error, reason}.
  """
  def invalidate_pattern(pattern) do
    context = %{action: :cache_invalidate_pattern, pattern: pattern}

    ErrorHandler.with_error_handling(fn ->
      deleted_count = :ets.select_delete(:ledger_cache, [{{:_, :_, :_}, [], [true]}])
      {:ok, deleted_count}
    end, context)
  end

  @doc """
  Gets account balance with caching and authorization.
  Returns {:ok, balance} or {:error, reason}.
  """
  def get_account_balance(account_id, user_id) do
    context = %{action: :get_account_balance, account_id: account_id, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      cache_key = "account_balance:#{account_id}"

      case get(cache_key) do
        {:ok, balance} -> {:ok, balance}
        {:error, %{error: %{type: :not_found}}} ->
          case LedgerBankApi.Banking.UserBankAccounts.get_account_balance(account_id, user_id) do
            {:ok, %{data: balance}} ->
              set(cache_key, balance, 60) # Cache for 1 minute
              {:ok, balance}
            error -> error
          end
      end
    end, context)
  end

  @doc """
  Invalidates account balance cache with standardized return pattern.
  Returns {:ok, :invalidated} or {:error, reason}.
  """
  def invalidate_account_balance(account_id) do
    context = %{action: :invalidate_account_balance, account_id: account_id}

    ErrorHandler.with_error_handling(fn ->
      delete("account_balance:#{account_id}")
    end, context)
  end

  @doc """
  Gets user accounts with caching and authorization.
  Returns {:ok, accounts} or {:error, reason}.
  """
  def get_user_accounts(user_id) do
    context = %{action: :get_user_accounts, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      cache_key = "user_accounts:#{user_id}"

      case get(cache_key) do
        {:ok, accounts} -> {:ok, accounts}
        {:error, %{error: %{type: :not_found}}} ->
          case LedgerBankApi.Banking.UserBankAccounts.list_for_user(user_id) do
            {:ok, %{data: accounts}} ->
              set(cache_key, accounts, 300) # Cache for 5 minutes
              {:ok, accounts}
            error -> error
          end
      end
    end, context)
  end

  @doc """
  Invalidates user accounts cache with standardized return pattern.
  Returns {:ok, :invalidated} or {:error, reason}.
  """
  def invalidate_user_accounts(user_id) do
    context = %{action: :invalidate_user_accounts, user_id: user_id}

    ErrorHandler.with_error_handling(fn ->
      delete("user_accounts:#{user_id}")
    end, context)
  end

  @doc """
  Gets active banks with caching.
  Returns {:ok, banks} or {:error, reason}.
  """
  def get_active_banks do
    context = %{action: :get_active_banks}

    ErrorHandler.with_error_handling(fn ->
      cache_key = "active_banks"

      case get(cache_key) do
        {:ok, banks} -> {:ok, banks}
        {:error, %{error: %{type: :not_found}}} ->
          case LedgerBankApi.Banking.Banks.list_active_banks() do
            {:ok, %{data: banks}} ->
              set(cache_key, banks, 3600) # Cache for 1 hour
              {:ok, banks}
            error -> error
          end
      end
    end, context)
  end

  @doc """
  Invalidates active banks cache with standardized return pattern.
  Returns {:ok, :invalidated} or {:error, reason}.
  """
  def invalidate_active_banks do
    context = %{action: :invalidate_active_banks}

    ErrorHandler.with_error_handling(fn ->
      delete("active_banks")
    end, context)
  end

  @doc """
  Gets cache statistics for monitoring.
  Returns {:ok, stats} or {:error, reason}.
  """
  def get_stats do
    context = %{action: :get_cache_stats}

    ErrorHandler.with_error_handling(fn ->
      total_entries = :ets.info(:ledger_cache, :size)
      memory_usage = :ets.info(:ledger_cache, :memory)

      {:ok, %{
        total_entries: total_entries,
        memory_usage_bytes: memory_usage,
        cache_ttl_seconds: @cache_ttl
      }}
    end, context)
  end

  @doc """
  Clears all cache entries with standardized return pattern.
  Returns {:ok, deleted_count} or {:error, reason}.
  """
  def clear_all do
    context = %{action: :clear_all_cache}

    ErrorHandler.with_error_handling(fn ->
      deleted_count = :ets.select_delete(:ledger_cache, [{{:_, :_, :_}, [], [true]}])
      {:ok, deleted_count}
    end, context)
  end
end

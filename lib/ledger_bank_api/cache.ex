defmodule LedgerBankApi.Cache do
  @moduledoc """
  Caching module for frequently accessed data.
  Provides TTL-based caching with automatic invalidation.
  """

  @cache_ttl 300 # 5 minutes default TTL

  @doc """
  Gets a value from cache.
  """
  def get(key) do
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
  end

  @doc """
  Sets a value in cache with TTL.
  """
  def set(key, value, ttl \\ @cache_ttl) do
    expires_at = DateTime.utc_now() |> DateTime.add(ttl, :second)
    :ets.insert(:ledger_cache, {key, value, expires_at})
    {:ok, value}
  end

  @doc """
  Deletes a value from cache.
  """
  def delete(key) do
    :ets.delete(:ledger_cache, key)
    :ok
  end

  @doc """
  Invalidates cache by pattern.
  """
  def invalidate_pattern(_pattern) do
    :ets.select_delete(:ledger_cache, [{{:_, :_, :_}, [], [true]}])
    :ok
  end

  @doc """
  Gets account balance with caching.
  """
  def get_account_balance(account_id) do
    cache_key = "account_balance:#{account_id}"

    case get(cache_key) do
      {:ok, balance} -> {:ok, balance}
      {:error, :not_found} ->
        case LedgerBankApi.Banking.UserBankAccounts.get_account_balance(account_id) do
          {:ok, balance} ->
            set(cache_key, balance, 60) # Cache for 1 minute
            {:ok, balance}
          error -> error
        end
    end
  end

  @doc """
  Invalidates account balance cache.
  """
  def invalidate_account_balance(account_id) do
    delete("account_balance:#{account_id}")
  end

  @doc """
  Gets user accounts with caching.
  """
  def get_user_accounts(user_id) do
    cache_key = "user_accounts:#{user_id}"

    case get(cache_key) do
      {:ok, accounts} -> {:ok, accounts}
      {:error, :not_found} ->
        accounts = LedgerBankApi.Banking.UserBankAccounts.list_for_user(user_id)
        set(cache_key, accounts, 300) # Cache for 5 minutes
        {:ok, accounts}
    end
  end

  @doc """
  Invalidates user accounts cache.
  """
  def invalidate_user_accounts(user_id) do
    delete("user_accounts:#{user_id}")
  end

  @doc """
  Gets active banks with caching.
  """
  def get_active_banks do
    cache_key = "active_banks"

    case get(cache_key) do
      {:ok, banks} -> {:ok, banks}
      {:error, :not_found} ->
        banks = LedgerBankApi.Banking.Banks.list_active_banks()
        set(cache_key, banks, 3600) # Cache for 1 hour
        {:ok, banks}
    end
  end

  @doc """
  Invalidates active banks cache.
  """
  def invalidate_active_banks do
    delete("active_banks")
  end
end

defmodule LedgerBankApi.Cache do
  @moduledoc """
  Enhanced caching module for frequently accessed data with comprehensive error handling.
  Provides TTL-based caching with automatic invalidation and standardized return patterns.
  All functions return {:ok, data} or {:error, reason} for consistency.
  """

  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  import LedgerBankApi.Database.CacheMacros

  @cache_ttl Application.compile_env(:ledger_bank_api, :cache_ttl, 300) # 5 minutes default TTL

  # Use common cache operations
  use_cache_operations()

  # Use typed cache operations for specific data types
  use_typed_cache_operations(:account_balance, "account_balance", 60)
  use_typed_cache_operations(:user_accounts, "user_accounts", 300)
  use_typed_cache_operations(:active_banks, "active_banks", 3600)


  @doc """
  Gets account balance with caching and authorization.
  Returns {:ok, balance} or {:error, reason}.
  """
  def get_account_balance(account_id, user_id) do
    get_account_balance_with_fallback(account_id, fn ->
      LedgerBankApi.Banking.get_account_balance(account_id, user_id)
    end)
  end

  @doc """
  Gets user accounts with caching and authorization.
  Returns {:ok, accounts} or {:error, reason}.
  """
  def get_user_accounts(user_id) do
    get_user_accounts_with_fallback(user_id, fn ->
      LedgerBankApi.Banking.list_user_bank_accounts_for_user(user_id, preload: [:user_bank_login, :user_payments])
    end)
  end

  @doc """
  Gets active banks with caching.
  Returns {:ok, banks} or {:error, reason}.
  """
  def get_active_banks do
    get_active_banks_with_fallback("all", fn ->
      LedgerBankApi.Banking.list_active_banks()
    end)
  end

end

defmodule LedgerBankApi.Banking.Context do
  @moduledoc """
  Enhanced Banking context with advanced querying, filtering, and pagination support.
  Provides optimized database operations using Ecto.Query for better performance.
  """

  import Ecto.Query, warn: false

  alias LedgerBankApi.Banking.Banks
  alias LedgerBankApi.Banking.BankBranches
  alias LedgerBankApi.Banking.UserBankLogins
  alias LedgerBankApi.Banking.UserBankAccounts
  alias LedgerBankApi.Banking.UserPayments
  alias LedgerBankApi.Banking.Transactions

  # Banks
  defdelegate list_banks(), to: Banks, as: :list
  defdelegate get_bank!(id), to: Banks, as: :get!
  defdelegate create_bank(attrs), to: Banks, as: :create
  defdelegate update_bank(bank, attrs), to: Banks, as: :update
  defdelegate delete_bank(bank), to: Banks, as: :delete
  defdelegate list_active_banks(), to: Banks, as: :list_active_banks

  # Bank Branches
  defdelegate list_bank_branches(), to: BankBranches, as: :list
  defdelegate get_bank_branch!(id), to: BankBranches, as: :get!
  defdelegate create_bank_branch(attrs), to: BankBranches, as: :create
  defdelegate update_bank_branch(branch, attrs), to: BankBranches, as: :update
  defdelegate delete_bank_branch(branch), to: BankBranches, as: :delete

  # User Bank Logins
  defdelegate list_user_bank_logins(), to: UserBankLogins, as: :list
  defdelegate get_user_bank_login!(id), to: UserBankLogins, as: :get!
  defdelegate create_user_bank_login(attrs), to: UserBankLogins, as: :create_user_bank_login
  defdelegate update_user_bank_login(login, attrs), to: UserBankLogins, as: :update
  defdelegate delete_user_bank_login(login), to: UserBankLogins, as: :delete
  defdelegate list_user_bank_logins_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserBankLogins, as: :list_with_filters
  defdelegate get_user_bank_login_with_preloads!(id, preloads), to: UserBankLogins, as: :get_with_preloads!

  # User Bank Accounts
  defdelegate list_user_bank_accounts(), to: UserBankAccounts, as: :list
  defdelegate get_user_bank_account!(id), to: UserBankAccounts, as: :get!
  defdelegate create_user_bank_account(attrs), to: UserBankAccounts, as: :create
  defdelegate update_user_bank_account(account, attrs), to: UserBankAccounts, as: :update
  defdelegate delete_user_bank_account(account), to: UserBankAccounts, as: :delete
  defdelegate list_user_bank_accounts_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserBankAccounts, as: :list_with_filters
  defdelegate get_user_bank_account_with_preloads!(id, preloads), to: UserBankAccounts, as: :get_with_preloads!

  # User Payments
  defdelegate list_user_payments(), to: UserPayments, as: :list
  defdelegate get_user_payment!(id), to: UserPayments, as: :get!
  defdelegate create_user_payment(attrs), to: UserPayments, as: :create
  defdelegate update_user_payment(payment, attrs), to: UserPayments, as: :update
  defdelegate delete_user_payment(payment), to: UserPayments, as: :delete
  defdelegate list_for_account(account_id), to: UserPayments, as: :list_for_account
  defdelegate list_pending(), to: UserPayments, as: :list_pending
  defdelegate list_user_payments_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserPayments, as: :list_with_filters
  defdelegate get_user_payment_with_preloads!(id, preloads), to: UserPayments, as: :get_with_preloads!

  # Transactions
  defdelegate list_transactions(), to: Transactions, as: :list
  defdelegate get_transaction!(id), to: Transactions, as: :get!
  defdelegate create_transaction(attrs), to: Transactions, as: :create
  defdelegate update_transaction(txn, attrs), to: Transactions, as: :update
  defdelegate delete_transaction(txn), to: Transactions, as: :delete
  defdelegate list_transactions_for_user_bank_account(account_id, opts \\ []), to: Transactions, as: :list_for_account
  defdelegate list_payments_for_user_bank_account(account_id), to: UserPayments, as: :list_for_account
  defdelegate list_transactions_with_filters(pagination, filters, sorting, user_id, user_filter), to: Transactions, as: :list_with_filters
  defdelegate get_transaction_with_preloads!(id, preloads), to: Transactions, as: :get_with_preloads!
  defdelegate list_payments_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserPayments, as: :list_with_filters
  defdelegate get_user_bank_account_with_preloads_and_user!(id, preloads, user_id), to: UserBankAccounts, as: :get_with_preloads_and_user!

  # Enhanced querying methods
  # Generic CRUD functions for crud_operations macro
  # These functions delegate to the appropriate specific functions based on the schema

  @doc """
  Generic create function that delegates to the appropriate specific create function.
  """
  def create(attrs) do
    case attrs do
      %{user_bank_account_id: _} -> create_user_payment(attrs)
      %{user_bank_login_id: _} -> create_user_bank_account(attrs)
      %{bank_id: _} -> create_user_bank_login(attrs)
      _ -> {:error, "Unknown resource type"}
    end
  end

  @doc """
  Generic update function that delegates to the appropriate specific update function.
  """
  def update(resource, attrs) do
    case resource do
      %LedgerBankApi.Banking.Schemas.UserPayment{} -> update_user_payment(resource, attrs)
      %LedgerBankApi.Banking.Schemas.UserBankAccount{} -> update_user_bank_account(resource, attrs)
      %LedgerBankApi.Banking.Schemas.UserBankLogin{} -> update_user_bank_login(resource, attrs)
      _ -> {:error, "Unknown resource type"}
    end
  end

  @doc """
  Generic delete function that delegates to the appropriate specific delete function.
  """
  def delete(resource) do
    case resource do
      %LedgerBankApi.Banking.Schemas.UserPayment{} -> delete_user_payment(resource)
      %LedgerBankApi.Banking.Schemas.UserBankAccount{} -> delete_user_bank_account(resource)
      %LedgerBankApi.Banking.Schemas.UserBankLogin{} -> delete_user_bank_login(resource)
      _ -> {:error, "Unknown resource type"}
    end
  end

  @doc """
  Generic get! function that delegates to the appropriate specific get! function.
  """
  def get!(id) do
    # Try each specific get! function until one succeeds
    try do
      get_user_payment!(id)
    rescue
      Ecto.Query.CastError ->
        try do
          get_user_bank_account!(id)
        rescue
          Ecto.Query.CastError ->
            try do
              get_user_bank_login!(id)
            rescue
              Ecto.Query.CastError ->
                raise "Resource not found"
            end
        end
    end
  end

  @doc """
  Generic get_with_preloads! function that delegates to the appropriate specific function.
  """
  def get_with_preloads!(id, preloads) do
    # Try each specific get_with_preloads! function until one succeeds
    try do
      get_user_payment_with_preloads!(id, preloads)
    rescue
      Ecto.Query.CastError ->
        try do
          get_user_bank_account_with_preloads!(id, preloads)
        rescue
          Ecto.Query.CastError ->
            try do
              get_user_bank_login_with_preloads!(id, preloads)
            rescue
              Ecto.Query.CastError ->
                raise "Resource not found"
            end
        end
    end
  end

  @doc """
  Generic list_with_filters function that delegates to the appropriate specific function.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    # For the banking controller, we want to list user bank accounts by default
    # since that's what the accounts endpoint should return
    list_user_bank_accounts_with_filters(pagination, filters, sorting, user_id, user_filter)
  end
end

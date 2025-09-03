defmodule LedgerBankApi.Banking.Context do
  @moduledoc """
  Enhanced Banking context with advanced querying, filtering, and pagination support.
  Provides optimized database operations using Ecto.Query for better performance.
  All functions return standardized {:ok, data} or {:error, reason} patterns.
  """

  import Ecto.Query, warn: false

  alias LedgerBankApi.Banking.Banks
  alias LedgerBankApi.Banking.BankBranches
  alias LedgerBankApi.Banking.UserBankLogins
  alias LedgerBankApi.Banking.UserBankAccounts
  alias LedgerBankApi.Banking.UserPayments
  alias LedgerBankApi.Banking.Transactions
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  # Banks
  defdelegate list_banks(), to: Banks, as: :list
  defdelegate get_bank!(id), to: Banks, as: :get!
  defdelegate create_bank(attrs), to: Banks, as: :create_bank
  defdelegate update_bank(bank, attrs), to: Banks, as: :update_bank
  defdelegate delete_bank(bank), to: Banks, as: :delete
  defdelegate list_active_banks(), to: Banks, as: :list_active_banks
  defdelegate list_banks_by_country(country), to: Banks, as: :list_by_country
  defdelegate get_bank_by_code(code), to: Banks, as: :get_by_code

  # Bank Branches
  defdelegate list_bank_branches(), to: BankBranches, as: :list
  defdelegate get_bank_branch!(id), to: BankBranches, as: :get!
  defdelegate create_bank_branch(attrs), to: BankBranches, as: :create_bank_branch
  defdelegate update_bank_branch(branch, attrs), to: BankBranches, as: :update_bank_branch
  defdelegate delete_bank_branch(branch), to: BankBranches, as: :delete
  defdelegate list_bank_branches_by_bank(bank_id), to: BankBranches, as: :list_by_bank
  defdelegate list_bank_branches_by_country(country), to: BankBranches, as: :list_by_country
  defdelegate get_bank_branch_by_iban(iban), to: BankBranches, as: :get_by_iban

  # User Bank Logins
  defdelegate list_user_bank_logins(), to: UserBankLogins, as: :list
  defdelegate get_user_bank_login!(id), to: UserBankLogins, as: :get!
  defdelegate create_user_bank_login(attrs), to: UserBankLogins, as: :create_user_bank_login
  defdelegate update_user_bank_login(login, attrs), to: UserBankLogins, as: :update_user_bank_login
  defdelegate delete_user_bank_login(login), to: UserBankLogins, as: :delete_user_bank_login
  defdelegate list_user_bank_logins_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserBankLogins, as: :list_with_filters
  defdelegate get_user_bank_login_with_preloads!(id, preloads), to: UserBankLogins, as: :get_user_bank_login_with_preloads!
  defdelegate get_logins_by_user(user_id, filters), to: UserBankLogins, as: :get_logins_by_user
  defdelegate update_login_status(login, status), to: UserBankLogins, as: :update_login_status
  defdelegate is_login_valid?(login), to: UserBankLogins, as: :is_login_valid?

  # User Bank Accounts
  defdelegate list_user_bank_accounts(), to: UserBankAccounts, as: :list
  defdelegate get_user_bank_account!(id), to: UserBankAccounts, as: :get!
  defdelegate create_user_bank_account(attrs, user_id), to: UserBankAccounts, as: :create_user_bank_account
  defdelegate update_user_bank_account(account, attrs, user_id), to: UserBankAccounts, as: :update_user_bank_account
  defdelegate delete_user_bank_account(account, user_id), to: UserBankAccounts, as: :delete_user_bank_account
  defdelegate list_user_bank_accounts_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserBankAccounts, as: :list_with_filters
  defdelegate get_user_bank_account_with_preloads!(id, preloads), to: UserBankAccounts, as: :get_with_preloads!
  defdelegate get_user_bank_account_balance(account_id, user_id), to: UserBankAccounts, as: :get_account_balance
  defdelegate update_user_bank_account_balance(account_id, new_balance, user_id), to: UserBankAccounts, as: :update_balance
  defdelegate list_user_bank_accounts_for_user(user_id, opts), to: UserBankAccounts, as: :list_for_user

  # User Payments
  defdelegate list_user_payments(), to: UserPayments, as: :list
  defdelegate get_user_payment!(id), to: UserPayments, as: :get!
  defdelegate create_user_payment(attrs, user_id), to: UserPayments, as: :create_payment
  defdelegate update_user_payment(payment, attrs), to: UserPayments, as: :update
  defdelegate delete_user_payment(payment), to: UserPayments, as: :delete
  defdelegate list_for_account(account_id), to: UserPayments, as: :list_for_account
  defdelegate list_pending(), to: UserPayments, as: :list_pending
  defdelegate list_user_payments_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserPayments, as: :list_with_filters
  defdelegate get_user_payment_with_preloads!(id, preloads), to: UserPayments, as: :get_with_preloads!
  defdelegate process_payment(payment_id), to: UserPayments, as: :process_payment

  # Transactions
  defdelegate list_transactions(), to: Transactions, as: :list
  defdelegate get_transaction!(id), to: Transactions, as: :get!
  defdelegate create_transaction(attrs), to: Transactions, as: :create_transaction
  defdelegate update_transaction(txn, attrs, user_id), to: Transactions, as: :update_transaction
  defdelegate delete_transaction(txn, user_id), to: Transactions, as: :delete_transaction
  defdelegate list_transactions_for_user_bank_account(account_id, user_id, opts \\ []), to: Transactions, as: :list_for_account
  defdelegate list_payments_for_user_bank_account(account_id), to: UserPayments, as: :list_for_account
  defdelegate list_transactions_with_filters(pagination, filters, sorting, user_id, user_filter), to: Transactions, as: :list_with_filters
  defdelegate get_transaction_with_preloads!(id, preloads), to: Transactions, as: :get_transaction_with_preloads!
  defdelegate get_transactions_by_account(account_id, user_id, filters), to: Transactions, as: :get_transactions_by_account
  defdelegate list_payments_with_filters(pagination, filters, sorting, user_id, user_filter), to: UserPayments, as: :list_with_filters
  defdelegate get_user_bank_account_with_preloads_and_user!(id, preloads, user_id), to: UserBankAccounts, as: :get_with_preloads_and_user!

  # Enhanced querying methods with standardized return patterns
  # Generic CRUD functions for crud_operations macro
  # These functions delegate to the appropriate specific functions based on the schema

  @doc """
  Generic create function that delegates to the appropriate specific create function.
  Returns {:ok, resource} or {:error, reason}.
  """
  def create(attrs, user_id \\ nil) do
    context = %{action: :create, resource_type: determine_resource_type(attrs)}

    ErrorHandler.with_error_handling(fn ->
      case attrs do
        %{user_bank_account_id: _} -> create_user_payment(attrs, user_id)
        %{user_bank_login_id: _} -> create_user_bank_account(attrs, user_id)
        %{bank_id: _} -> create_user_bank_login(attrs)
        _ -> {:error, "Unknown resource type"}
      end
    end, context)
  end

  @doc """
  Generic update function that delegates to the appropriate specific update function.
  Returns {:ok, resource} or {:error, reason}.
  """
  def update(resource, attrs, user_id \\ nil) do
    context = %{action: :update, resource_type: get_resource_type(resource)}

    ErrorHandler.with_error_handling(fn ->
      case resource do
        %LedgerBankApi.Banking.Schemas.UserPayment{} -> update_user_payment(resource, attrs)
        %LedgerBankApi.Banking.Schemas.UserBankAccount{} -> update_user_bank_account(resource, attrs, user_id)
        %LedgerBankApi.Banking.Schemas.UserBankLogin{} -> update_user_bank_login(resource, attrs)
        _ -> {:error, "Unknown resource type"}
      end
    end, context)
  end

  @doc """
  Generic delete function that delegates to the appropriate specific delete function.
  Returns {:ok, resource} or {:error, reason}.
  """
  def delete(resource, user_id \\ nil) do
    context = %{action: :delete, resource_type: get_resource_type(resource)}

    ErrorHandler.with_error_handling(fn ->
      case resource do
        %LedgerBankApi.Banking.Schemas.UserPayment{} -> delete_user_payment(resource)
        %LedgerBankApi.Banking.Schemas.UserBankAccount{} -> delete_user_bank_account(resource, user_id)
        %LedgerBankApi.Banking.Schemas.UserBankLogin{} -> delete_user_bank_login(resource)
        _ -> {:error, "Unknown resource type"}
      end
    end, context)
  end

  @doc """
  Generic get! function that delegates to the appropriate specific get! function.
  Returns {:ok, resource} or {:error, reason}.
  """
  def get!(id) do
    context = %{action: :get, id: id}

    ErrorHandler.with_error_handling(fn ->
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
                  {:error, :not_found}
              end
          end
      end
    end, context)
  end

  @doc """
  Generic get_with_preloads! function that delegates to the appropriate specific function.
  Returns {:ok, resource} or {:error, reason}.
  """
  def get_with_preloads!(id, preloads) do
    context = %{action: :get_with_preloads, id: id, preloads: preloads}

    ErrorHandler.with_error_handling(fn ->
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
                  {:error, :not_found}
              end
          end
      end
    end, context)
  end

  @doc """
  Generic list_with_filters function that delegates to the appropriate specific function.
  Returns {:ok, %{data: list, pagination: map}} or {:error, reason}.
  """
  def list_with_filters(pagination, filters, sorting, user_id, user_filter) do
    context = %{action: :list_with_filters, user_id: user_id, user_filter: user_filter}

    ErrorHandler.with_error_handling(fn ->
      # For the banking controller, we want to list user bank accounts by default
      # since that's what the accounts endpoint should return
      list_user_bank_accounts_with_filters(pagination, filters, sorting, user_id, user_filter)
    end, context)
  end

  # Private helper functions

  defp determine_resource_type(attrs) do
    cond do
      Map.has_key?(attrs, :user_bank_account_id) or Map.has_key?(attrs, "user_bank_account_id") -> :user_payment
      Map.has_key?(attrs, :user_bank_login_id) or Map.has_key?(attrs, "user_bank_login_id") -> :user_bank_account
      Map.has_key?(attrs, :bank_id) or Map.has_key?(attrs, "bank_id") -> :user_bank_login
      true -> :unknown
    end
  end

  defp get_resource_type(resource) do
    case resource do
      %LedgerBankApi.Banking.Schemas.UserPayment{} -> :user_payment
      %LedgerBankApi.Banking.Schemas.UserBankAccount{} -> :user_bank_account
      %LedgerBankApi.Banking.Schemas.UserBankLogin{} -> :user_bank_login
      _ -> :unknown
    end
  end
end

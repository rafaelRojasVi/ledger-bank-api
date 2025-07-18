defmodule LedgerBankApi.Banking.Context do
  @moduledoc """
  The Banking context for LedgerBankApi.
  Delegates to resource-specific modules for business logic.
  """

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

  # User Bank Accounts
  defdelegate list_user_bank_accounts(), to: UserBankAccounts, as: :list
  defdelegate get_user_bank_account!(id), to: UserBankAccounts, as: :get!
  defdelegate create_user_bank_account(attrs), to: UserBankAccounts, as: :create
  defdelegate update_user_bank_account(account, attrs), to: UserBankAccounts, as: :update
  defdelegate delete_user_bank_account(account), to: UserBankAccounts, as: :delete

  # User Payments
  defdelegate list_user_payments(), to: UserPayments, as: :list
  defdelegate get_user_payment!(id), to: UserPayments, as: :get!
  defdelegate create_user_payment(attrs), to: UserPayments, as: :create
  defdelegate update_user_payment(payment, attrs), to: UserPayments, as: :update
  defdelegate delete_user_payment(payment), to: UserPayments, as: :delete
  defdelegate list_for_account(account_id), to: UserPayments, as: :list_for_account
  defdelegate list_pending(), to: UserPayments, as: :list_pending

  # Transactions
  defdelegate list_transactions(), to: Transactions, as: :list
  defdelegate get_transaction!(id), to: Transactions, as: :get!
  defdelegate create_transaction(attrs), to: Transactions, as: :create
  defdelegate update_transaction(txn, attrs), to: Transactions, as: :update
  defdelegate delete_transaction(txn), to: Transactions, as: :delete
  defdelegate list_transactions_for_user_bank_account(account_id, opts \\ []), to: Transactions, as: :list_for_account
  defdelegate list_payments_for_user_bank_account(account_id), to: UserPayments, as: :list_for_account
end

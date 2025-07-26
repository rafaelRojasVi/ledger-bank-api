defmodule LedgerBankApiWeb.BankingJSONV2 do
  @moduledoc """
  Optimized banking JSON view using base JSON patterns.
  Provides standardized response formatting for banking endpoints.
  """

  import LedgerBankApiWeb.JSON.BaseJSON

  @doc """
  Renders a list of accounts.
  """
  def index(%{user_bank_account: accounts}) do
    list_response(accounts, :account)
  end

  @doc """
  Renders a single account.
  """
  def show(%{user_bank_account: account}) do
    show_response(account, :account)
  end

  @doc """
  Renders account payments.
  """
  def payments(%{payments: payments, account: account}) do
    %{
      data: Enum.map(payments, &format_payment/1),
      account: format_account(account)
    }
  end

  @doc """
  Renders account transactions.
  """
  def transactions(%{transactions: transactions, account: account}) do
    %{
      data: Enum.map(transactions, &format_transaction/1),
      account: format_account(account)
    }
  end

  @doc """
  Renders account balances.
  """
  def balances(%{account: account}) do
    format_balance_response(account)
  end
end

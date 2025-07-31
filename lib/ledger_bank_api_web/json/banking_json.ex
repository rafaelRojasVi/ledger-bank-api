defmodule LedgerBankApiWeb.BankingJSON do
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

  def index(%{accounts: accounts}) do
    list_response(accounts, :account)
  end

  def index(assigns) when is_map(assigns) do
    # Handle case where data might be passed directly
    case Map.get(assigns, :data) do
      nil -> %{data: []}
      data -> list_response(data, :account)
    end
  end

  @doc """
  Renders a single account.
  """
  def show(%{user_bank_account: account}) do
    %{data: %{account: LedgerBankApiWeb.JSON.AccountJSON.format(account)}}
  end

  def show(%{account: account}) do
    %{data: %{account: LedgerBankApiWeb.JSON.AccountJSON.format(account)}}
  end

  @doc """
  Renders account payments.
  """
  def payments(%{payments: payments, account: account}) do
    %{
      data: Enum.map(payments, &LedgerBankApiWeb.JSON.PaymentJSON.format/1),
      account: LedgerBankApiWeb.JSON.AccountJSON.format(account)
    }
  end

  @doc """
  Renders account transactions.
  """
  def transactions(%{transactions: transactions, account: account}) do
    %{
      data: Enum.map(transactions, &LedgerBankApiWeb.JSON.TransactionJSON.format/1),
      account: LedgerBankApiWeb.JSON.AccountJSON.format(account)
    }
  end

  @doc """
  Renders account balances.
  """
  def balances(%{account: account}) do
    LedgerBankApiWeb.JSON.AccountJSON.format_balance_response(account)
  end

  def render("transactions.json", assigns), do: transactions(assigns)
  def render("payments.json", assigns), do: payments(assigns)
  def render("balances.json", assigns), do: balances(assigns)
  def render("index.json", assigns), do: index(assigns)
  def render("show.json", assigns), do: show(assigns)
end

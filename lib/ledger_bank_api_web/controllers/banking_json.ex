defmodule LedgerBankApiWeb.BankingJSON do
  @doc """
  Renders a list of accounts (like Teller.io).
  """
  def index(%{accounts: accounts}) do
    %{data: for(account <- accounts, do: account_data(account))}
  end

  @doc """
  Renders a single account (like Teller.io).
  """
  def show(%{account: account}) do
    %{data: account_data(account)}
  end

  @doc """
  Renders account transactions.
  """
  def transactions(%{result: result, account: account}) do
    %{
      data: for(transaction <- result.data, do: transaction_data(transaction)),
      account: account_data(account),
      pagination: result.pagination
    }
  end

  @doc """
  Renders account balances.
  """
  def balances(%{account: account}) do
    %{
      data: %{
        account_id: account.id,
        balance: account.balance,
        currency: account.currency,
        last_updated: account.last_sync_at
      }
    }
  end

  @doc """
  Renders account payments.
  """
  def payments(%{payments: payments, account: account}) do
    %{
      data: for(payment <- payments, do: payment_data(payment)),
      account: account_data(account)
    }
  end

  defp account_data(account) do
    %{
      id: account.id,
      name: account.account_name,
      status: account.status,
      type: account.account_type,
      currency: account.currency,
      institution: %{
        id: account.user_bank_login.bank_branch.bank.id,
        name: account.user_bank_login.bank_branch.bank.name
      },
      last_four: account.last_four,
      balance: account.balance,
      last_sync_at: account.last_sync_at,
      links: %{
        self: "/api/accounts/#{account.id}",
        transactions: "/api/accounts/#{account.id}/transactions",
        balances: "/api/accounts/#{account.id}/balances",
        payments: "/api/accounts/#{account.id}/payments"
      }
    }
  end

  defp transaction_data(transaction) do
    %{
      id: transaction.id,
      account_id: transaction.account_id,
      description: transaction.description,
      amount: transaction.amount,
      posted_at: transaction.posted_at,
      type: "transaction"
    }
  end

  defp payment_data(payment) do
    %{
      id: payment.id,
      account_id: payment.user_bank_account_id,
      description: payment.description,
      amount: payment.amount,
      payment_type: payment.payment_type,
      status: payment.status,
      posted_at: payment.posted_at,
      type: "payment"
    }
  end
end

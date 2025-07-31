defmodule LedgerBankApiWeb.JSON.TransactionJSON do
  @moduledoc """
  JSON formatting for transaction data.
  """

  @doc """
  Format transaction data consistently.
  """
  def format(transaction) do
    %{
      id: transaction.id,
      account_id: transaction.account_id,
      description: transaction.description,
      amount: transaction.amount,
      direction: transaction.direction,
      posted_at: transaction.posted_at,
      type: "transaction",
      created_at: transaction.inserted_at
    }
  end
end

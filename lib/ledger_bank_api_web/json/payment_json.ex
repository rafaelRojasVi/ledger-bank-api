defmodule LedgerBankApiWeb.JSON.PaymentJSON do
  @moduledoc """
  JSON formatting for payment data.
  """

  @doc """
  Format payment data consistently.
  """
  def format(payment) do
    %{
      id: payment.id,
      amount: payment.amount,
      direction: payment.direction,
      description: payment.description,
      payment_type: payment.payment_type,
      status: payment.status,
      posted_at: payment.posted_at,
      external_transaction_id: payment.external_transaction_id,
      user_bank_account: LedgerBankApiWeb.JSON.AccountJSON.format_summary(payment.user_bank_account),
      created_at: payment.inserted_at,
      updated_at: payment.updated_at
    }
  end
end

# lib/ledger_bank_api_web/controllers/transaction_controller.ex
defmodule LedgerBankApiWeb.TransactionController do
  use LedgerBankApiWeb.ResourceController,
        context: LedgerBankApi.Banking,
        resource: :transaction

  # Only /index exists, so override it:
  @impl true
  def index(conn, %{"id" => account_id}) do
    case LedgerBankApi.Banking.get_account(account_id) do
      nil  -> {:error, :not_found}
      _    ->
        txns = LedgerBankApi.Banking.list_transactions(account_id)
        render(conn, :index, transactions: txns)
    end
  end
end

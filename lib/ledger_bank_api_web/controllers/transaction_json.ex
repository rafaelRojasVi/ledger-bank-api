# lib/ledger_bank_api_web/controllers/transaction_json.ex
defmodule LedgerBankApiWeb.TransactionJSON do
  use LedgerBankApiWeb.ResourceJSON,
      resource: :transaction,
      fields:   ~w(id amount posted_at description)a
end

# lib/ledger_bank_api_web/controllers/account_json.ex
defmodule LedgerBankApiWeb.AccountJSON do
  use LedgerBankApiWeb.ResourceJSON,
      resource: :account,
      fields:   ~w(id institution type last4 balance)a
end

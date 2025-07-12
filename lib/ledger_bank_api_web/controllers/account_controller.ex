# lib/ledger_bank_api_web/controllers/account_controller.ex
defmodule LedgerBankApiWeb.AccountController do
  use LedgerBankApiWeb.ResourceController,
        context: LedgerBankApi.Banking,
        resource: :account
end

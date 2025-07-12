defmodule LedgerBankApi.Repo do
  use Ecto.Repo,
    otp_app: :ledger_bank_api,
    adapter: Ecto.Adapters.Postgres
end

defmodule LedgerBankApi.Repo do
  @moduledoc """
  Ecto repository for LedgerBankApi.
  Handles database interactions using the Postgres adapter.
  """
  use Ecto.Repo,
    otp_app: :ledger_bank_api,
    adapter: Ecto.Adapters.Postgres
end

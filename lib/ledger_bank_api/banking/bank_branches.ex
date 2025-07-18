defmodule LedgerBankApi.Banking.BankBranches do
  @moduledoc "Business logic for bank branches."
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Repo
  use LedgerBankApi.CrudHelpers, schema: BankBranch
end

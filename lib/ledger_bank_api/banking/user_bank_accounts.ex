defmodule LedgerBankApi.Banking.UserBankAccounts do
  @moduledoc "Business logic for user bank accounts."
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Repo
  use LedgerBankApi.CrudHelpers, schema: UserBankAccount
end

defmodule LedgerBankApi.Banking.Transactions do
  @moduledoc "Business logic for transactions."
  import Ecto.Query
  alias LedgerBankApi.Banking.Schemas.Transaction
  alias LedgerBankApi.Repo
  use LedgerBankApi.CrudHelpers, schema: Transaction

  def list_for_account(account_id, _opts \\ []) do
    Transaction
    |> where([t], t.account_id == ^account_id)
    |> Repo.all()
  end
end

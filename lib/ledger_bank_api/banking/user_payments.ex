defmodule LedgerBankApi.Banking.UserPayments do
  @moduledoc "Business logic for user payments."
  alias LedgerBankApi.Banking.Schemas.UserPayment
  alias LedgerBankApi.Repo
  import Ecto.Query
  use LedgerBankApi.CrudHelpers, schema: UserPayment

  def list_for_account(account_id) do
    UserPayment
    |> where([p], p.user_bank_account_id == ^account_id)
    |> order_by([p], desc: p.posted_at)
    |> Repo.all()
  end

  def list_pending do
    UserPayment |> where([p], p.status == "PENDING") |> Repo.all()
  end
end

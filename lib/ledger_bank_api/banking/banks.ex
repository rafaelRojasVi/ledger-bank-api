defmodule LedgerBankApi.Banking.Banks do
  @moduledoc "Business logic for banks."
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Repo
  import Ecto.Query
  use LedgerBankApi.CrudHelpers, schema: Bank

  def list_active_banks do
    Bank |> where([b], b.status == "ACTIVE") |> Repo.all()
  end
end

defmodule LedgerBankApi.Banking.BankBranchesTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.BankBranches
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create/1 creates a bank branch" do
    bank = Repo.insert!(%Bank{
      name: "Monzo",
      country: "UK",
      code: "MONZO_UK",
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    })
    attrs = %{name: "Main Branch", iban: "IBAN123", country: "UK", bank_id: bank.id}
    assert {:ok, %BankBranch{} = branch} = BankBranches.create(attrs)
    assert branch.name == "Main Branch"
  end

  test "list/0 returns all bank branches" do
    bank = Repo.insert!(%Bank{
      name: "Monzo",
      country: "UK",
      code: "MONZO_UK",
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    })
    BankBranches.create(%{name: "Branch1", iban: "IBAN456", country: "UK", bank_id: bank.id})
    assert length(BankBranches.list()) > 0
  end
end

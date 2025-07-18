defmodule LedgerBankApi.Banking.BanksTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.Banks
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create/1 creates a bank" do
    attrs = %{name: "Test Bank", country: "US", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"}
    assert {:ok, %Bank{} = bank} = Banks.create(attrs)
    assert bank.name == "Test Bank"
  end

  test "list/0 returns all banks" do
    Banks.create(%{name: "Bank1", country: "US", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"})
    assert length(Banks.list()) > 0
  end
end

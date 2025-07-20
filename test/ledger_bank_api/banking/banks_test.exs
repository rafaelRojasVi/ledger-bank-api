defmodule LedgerBankApi.Banking.BanksTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.Banks
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create/1 creates a bank" do
    attrs = %{name: "Monzo", country: "UK", code: "MONZO_UK", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"}
    assert {:ok, %Bank{} = bank} = Banks.create(attrs)
    assert bank.name == "Monzo"
    assert bank.code == "MONZO_UK"
  end

  test "list/0 returns all banks" do
    Banks.create(%{name: "Lloyds", country: "UK", code: "LLOYDS_UK", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"})
    assert length(Banks.list()) > 0
  end

  test "create/1 enforces unique code" do
    Banks.create(%{name: "Monzo", country: "UK", code: "MONZO_UK", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"})
    attrs = %{name: "Monzo2", country: "UK", code: "MONZO_UK", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"}
    assert {:error, changeset} = Banks.create(attrs)
    assert {:code, {"has already been taken", _}} = Enum.find(changeset.errors, fn {k, _} -> k == :code end)
  end

  test "create/1 enforces unique name" do
    Banks.create(%{name: "Lloyds", country: "UK", code: "LLOYDS_UK", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"})
    attrs = %{name: "Lloyds", country: "UK", code: "LLOYDS_UK_2", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"}
    assert {:error, changeset} = Banks.create(attrs)
    assert {:name, {"has already been taken", _}} = Enum.find(changeset.errors, fn {k, _} -> k == :name end)
  end

  test "code format is validated" do
    attrs = %{name: "Monzo", country: "UK", code: "INVALID CODE!", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"}
    assert {:error, changeset} = Banks.create(attrs)
    assert {:code, {"has invalid format", _}} = Enum.find(changeset.errors, fn {k, _} -> k == :code end)
  end

  test "code length is validated" do
    attrs = %{name: "Lloyds", country: "UK", code: "ab", integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"}
    assert {:error, changeset} = Banks.create(attrs)
    {:code, {msg, opts}} = Enum.find(changeset.errors, fn {k, _} -> k == :code end)
    assert msg == "should be at least %{count} character(s)"
    assert Keyword.get(opts, :count) == 3
  end
end

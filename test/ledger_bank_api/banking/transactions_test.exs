defmodule LedgerBankApi.Banking.TransactionsTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.Transactions
  alias LedgerBankApi.Banking.Schemas.Transaction
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create/1 creates a transaction" do
    bank = Repo.insert!(%Bank{
      name: "Test Bank",
      country: "US",
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    })
    branch = Repo.insert!(%BankBranch{
      name: "Test Branch",
      iban: "IBAN123",
      country: "US",
      bank_id: bank.id
    })
    user = Repo.insert!(%User{
      email: "test@example.com",
      full_name: "Test User",
      status: "ACTIVE"
    })
    login = Repo.insert!(%UserBankLogin{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "test",
      encrypted_password: "pw"
    })
    account = Repo.insert!(%UserBankAccount{
      user_bank_login_id: login.id,
      currency: "USD",
      account_type: "CHECKING"
    })
    attrs = %{account_id: account.id, amount: Decimal.new("100.00"), posted_at: DateTime.utc_now(), description: "Test Txn"}
    assert {:ok, %Transaction{} = txn} = Transactions.create(attrs)
    assert txn.amount == Decimal.new("100.00")
  end

  test "list_for_account/2 returns transactions for account" do
    bank = Repo.insert!(%Bank{
      name: "Test Bank",
      country: "US",
      integration_module: "Elixir.LedgerBankApi.Banking.Integrations.MonzoClient"
    })
    branch = Repo.insert!(%BankBranch{
      name: "Test Branch",
      iban: "IBAN123",
      country: "US",
      bank_id: bank.id
    })
    user = Repo.insert!(%User{
      email: "test@example.com",
      full_name: "Test User",
      status: "ACTIVE"
    })
    login = Repo.insert!(%UserBankLogin{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "test",
      encrypted_password: "pw"
    })
    account = Repo.insert!(%UserBankAccount{
      user_bank_login_id: login.id,
      currency: "USD",
      account_type: "CHECKING"
    })
    Transactions.create(%{account_id: account.id, amount: Decimal.new("50.00"), posted_at: DateTime.utc_now(), description: "A"})
    txns = Transactions.list_for_account(account.id)
    assert Enum.all?(txns, &(&1.account_id == account.id))
  end
end

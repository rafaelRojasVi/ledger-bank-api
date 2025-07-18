defmodule LedgerBankApi.Banking.UserBankAccountsTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.UserBankAccounts
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create/1 creates a user bank account" do
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
    attrs = %{user_bank_login_id: login.id, currency: "USD", account_type: "CHECKING"}
    assert {:ok, %UserBankAccount{} = account} = UserBankAccounts.create(attrs)
    assert account.currency == "USD"
  end

  test "list/0 returns all user bank accounts" do
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
    UserBankAccounts.create(%{user_bank_login_id: login.id, currency: "USD", account_type: "CHECKING"})
    assert length(UserBankAccounts.list()) > 0
  end
end

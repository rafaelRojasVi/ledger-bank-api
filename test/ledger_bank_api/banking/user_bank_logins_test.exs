defmodule LedgerBankApi.Banking.UserBankLoginsTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.UserBankLogins
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create_user_bank_login/1 creates a login" do
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
    attrs = %{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "test",
      encrypted_password: "pw"
    }
    assert {:ok, %UserBankLogin{} = login} = UserBankLogins.create_user_bank_login(attrs)
    assert login.username == "test"
  end
end

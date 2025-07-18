defmodule LedgerBankApi.Banking.UserPaymentsTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.UserPayments
  alias LedgerBankApi.Banking.Schemas.UserPayment
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create/1 creates a user payment" do
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
    attrs = %{user_bank_account_id: account.id, amount: Decimal.new("20.00"), payment_type: "PAYMENT", status: "PENDING"}
    assert {:ok, %UserPayment{} = payment} = UserPayments.create(attrs)
    assert payment.amount == Decimal.new("20.00")
  end

  test "list_for_account/1 returns payments for account" do
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
    UserPayments.create(%{user_bank_account_id: account.id, amount: Decimal.new("10.00"), payment_type: "PAYMENT", status: "PENDING"})
    payments = UserPayments.list_for_account(account.id)
    assert Enum.all?(payments, &(&1.user_bank_account_id == account.id))
  end
end

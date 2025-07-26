defmodule LedgerBankApi.Banking.DeletionWithDependenciesTest do
  use ExUnit.Case, async: false
  alias LedgerBankApi.Banking.Schemas.{Bank, BankBranch, UserBankLogin, UserBankAccount, UserPayment}
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Create user
    {:ok, user} = %User{}
    |> User.changeset(%{
      email: "dep@b.com",
      full_name: "Dep User",
      status: "ACTIVE",
      role: "user",
      password: "password123"
    })
    |> Repo.insert()

    # Create bank
    {:ok, bank} = %Bank{}
    |> Bank.changeset(%{
      name: "DepBank",
      country: "US",
      code: "DEPBANK_US"
    })
    |> Repo.insert()

    # Create branch
    {:ok, branch} = %BankBranch{}
    |> BankBranch.changeset(%{
      name: "Main",
      country: "US",
      bank_id: bank.id
    })
    |> Repo.insert()

    # Create login
    {:ok, login} = %UserBankLogin{}
    |> UserBankLogin.changeset(%{
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "dep",
      encrypted_password: "pw"
    })
    |> Repo.insert()

    # Create account
    {:ok, account} = %UserBankAccount{}
    |> UserBankAccount.changeset(%{
      user_bank_login_id: login.id,
      currency: "USD",
      account_type: "CHECKING"
    })
    |> Repo.insert()

    # Create payment
    {:ok, payment} = %UserPayment{}
    |> UserPayment.changeset(%{
      user_bank_account_id: account.id,
      amount: Decimal.new("10.00"),
      payment_type: "PAYMENT",
      status: "PENDING",
      direction: "DEBIT"
    })
    |> Repo.insert()

    %{user: user, bank: bank, branch: branch, login: login, account: account, payment: payment}
  end

  test "cannot delete bank with dependent branches", %{bank: bank} do
    assert_raise Ecto.ConstraintError, ~r/user_bank_logins_bank_branch_id_fkey/, fn ->
      Repo.delete(bank)
    end
  end

  test "cannot delete branch with dependent logins", %{branch: branch} do
    assert_raise Ecto.ConstraintError, ~r/user_bank_logins_bank_branch_id_fkey/, fn ->
      Repo.delete(branch)
    end
  end

  test "cannot delete login with dependent accounts", %{login: login} do
    assert_raise Ecto.ConstraintError, ~r/user_bank_accounts_user_bank_login_id_fkey/, fn ->
      Repo.delete(login)
    end
  end

    test "cannot delete account with dependent payments", %{account: account} do
    assert_raise Ecto.ConstraintError, ~r/user_payments_user_bank_account_id_fkey/, fn ->
      Repo.delete(account)
    end
  end

  test "can delete payment and then delete account", %{account: account, payment: payment} do
    assert {:ok, _} = Repo.delete(payment)
    assert {:ok, _} = Repo.delete(account)
  end
end

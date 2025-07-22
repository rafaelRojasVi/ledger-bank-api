defmodule LedgerBankApi.Banking.UserPaymentsPerformanceTest do
  use ExUnit.Case, async: false
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
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    user = Repo.insert!(%User{email: "perf@b.com", full_name: "Perf User", status: "ACTIVE", role: "user", password_hash: "hash"})
    bank = Repo.insert!(%Bank{name: "PerfBank", country: "US", code: "PERFBANK_US"})
    branch = Repo.insert!(%BankBranch{name: "Main", country: "US", bank_id: bank.id})
    login = Repo.insert!(%UserBankLogin{user_id: user.id, bank_branch_id: branch.id, username: "perf", encrypted_password: "pw"})
    account = Repo.insert!(%UserBankAccount{user_bank_login_id: login.id, currency: "USD", account_type: "CHECKING"})
    %{account: account}
  end

  test "concurrent payment creation", %{account: account} do
    results =
      1..100
      |> Task.async_stream(fn _ ->
        UserPayments.create(%{
          user_bank_account_id: account.id,
          amount: Decimal.new("1.00"),
          payment_type: "PAYMENT",
          status: "PENDING",
          direction: "DEBIT"
        })
      end, max_concurrency: 10)
      |> Enum.to_list()

    assert Enum.count(results) == 100
    assert Enum.all?(results, fn {:ok, {:ok, %UserPayment{}}} -> true; _ -> false end)
    assert Repo.aggregate(UserPayment, :count, :id) >= 100
  end
end

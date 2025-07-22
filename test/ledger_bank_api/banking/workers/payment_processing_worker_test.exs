defmodule LedgerBankApi.Workers.PaymentWorkerTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Workers.PaymentWorker
  alias LedgerBankApi.Banking.Schemas.UserPayment
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  alias LedgerBankApi.Banking.Schemas.UserBankLogin
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  test "perform/1 processes payment successfully" do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    user = Repo.insert!(%User{email: "test@pay.com", full_name: "Pay User", status: "ACTIVE", role: "user", password_hash: "hash"})
    bank = Repo.insert!(%Bank{name: "PayBank", country: "US", code: "PAYBANK_US"})
    branch = Repo.insert!(%BankBranch{name: "Main", country: "US", bank_id: bank.id})
    login = Repo.insert!(%UserBankLogin{user_id: user.id, bank_branch_id: branch.id, username: "pay", encrypted_password: "pw"})
    account = Repo.insert!(%UserBankAccount{user_bank_login_id: login.id, currency: "USD", account_type: "CHECKING"})
    payment = Repo.insert!(%UserPayment{
      user_bank_account_id: account.id,
      amount: Decimal.new("10.00"),
      payment_type: "PAYMENT",
      status: "PENDING",
      direction: "DEBIT"
    })
    job = %Oban.Job{args: %{"payment_id" => payment.id}}
    result = PaymentWorker.perform(job)
    assert {:ok, %{data: %{data: {:ok, txn}}, success: true, timestamp: _, metadata: _}} = result
    assert %LedgerBankApi.Banking.Schemas.Transaction{} = txn
  end

  test "perform/1 handles errors gracefully" do
    # Simulate error by raising inside the worker
    defmodule ErrorWorker do
      use Oban.Worker, queue: :payments
      alias LedgerBankApi.Banking.Behaviours.ErrorHandler
      def perform(_job), do: ErrorHandler.with_error_handling(fn -> raise "fail" end, %{})
    end
    job = %Oban.Job{args: %{"payment_id" => "fail"}}
    assert {:error, %{error: %{type: :internal_server_error}}} = ErrorWorker.perform(job)
  end
end

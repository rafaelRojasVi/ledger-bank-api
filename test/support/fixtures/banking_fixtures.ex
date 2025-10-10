defmodule LedgerBankApi.BankingFixtures do
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Financial.Schemas.{UserBankLogin, UserBankAccount, UserPayment, Transaction, Bank, BankBranch}

  def bank_fixture(attrs \\ %{}) do
    base = %{
      name: "TestBank#{abs(System.unique_integer())}",  # Use absolute value to avoid negative signs
      code: "TB#{abs(System.unique_integer())}",        # Use absolute value to avoid negative signs
      country: "GB",
      status: "ACTIVE"
    }

    {:ok, bank} = %Bank{} |> Bank.changeset(Map.merge(base, attrs)) |> Repo.insert()
    bank
  end

  def bank_branch_fixture(bank, attrs \\ %{}) do
    base = %{
      name: "TestBranch#{abs(System.unique_integer())}",  # Use absolute value to avoid negative signs
      country: "GB",                                      # Required field - 2-letter country code
      bank_id: bank.id
    }

    {:ok, branch} = %BankBranch{} |> BankBranch.changeset(Map.merge(base, attrs)) |> Repo.insert()
    branch
  end

  def login_fixture(user, attrs \\ %{}) do
    # Create a bank and branch first
    bank = bank_fixture()
    branch = bank_branch_fixture(bank)

    base = %{
      provider: "monzo",
      status: "ACTIVE",
      external_login_id: "login_#{System.unique_integer()}",
      user_id: user.id,
      bank_branch_id: branch.id,
      username: "testuser#{abs(System.unique_integer())}",
      encrypted_password: "encrypted_password_#{System.unique_integer()}"
    }

    {:ok, login} = %UserBankLogin{} |> UserBankLogin.changeset(Map.merge(base, attrs)) |> Repo.insert()
    login
  end

  def account_fixture(login, attrs \\ %{}) do
    base = %{
      account_name: "Main Account",
      account_type: "CHECKING",
      currency: "GBP",
      balance: Decimal.new("1000.00"),
      user_bank_login_id: login.id,
      user_id: login.user_id
    }

    {:ok, account} =
      %UserBankAccount{} |> UserBankAccount.changeset(Map.merge(base, attrs)) |> Repo.insert()

    account
  end

  def payment_fixture(account, attrs \\ %{}) do
    base = %{
      amount: Decimal.new("50.00"),
      direction: "DEBIT",
      description: "Test Payment",
      status: "PENDING",
      payment_type: "PAYMENT",  # Required field
      user_bank_account_id: account.id,
      user_id: account.user_id
    }

    {:ok, payment} = %UserPayment{} |> UserPayment.changeset(Map.merge(base, attrs)) |> Repo.insert()
    payment
  end

  def transaction_fixture(account, attrs \\ %{}) do
    base = %{
      amount: Decimal.new("25.00"),
      direction: "DEBIT",
      description: "Test Transaction",
      posted_at: DateTime.utc_now(),
      user_bank_account_id: account.id,
      account_id: account.id,
      user_id: account.user_id
    }

    {:ok, transaction} = %Transaction{} |> Transaction.changeset(Map.merge(base, attrs)) |> Repo.insert()
    transaction
  end
end

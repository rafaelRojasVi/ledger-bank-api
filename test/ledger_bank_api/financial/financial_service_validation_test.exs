defmodule LedgerBankApi.Financial.FinancialServiceValidationTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Financial.FinancialService
  import LedgerBankApi.BankingFixtures
  import LedgerBankApi.UsersFixtures

  setup do
    user = user_fixture()
    login = login_fixture(user)
    account = account_fixture(login, %{balance: Decimal.new("1000.00"), account_type: "CHECKING"})

    payment =
      payment_fixture(account, %{
        user_id: user.id,
        amount: Decimal.new("100.00"),
        direction: "DEBIT"
      })

    %{user: user, login: login, account: account, payment: payment}
  end

  describe "validate_account_active/1" do
    test "returns :ok for active account", %{account: account} do
      assert :ok = FinancialService.validate_account_active(account)
    end

    test "returns error for inactive account", %{login: login} do
      inactive_account = account_fixture(login, %{status: "INACTIVE"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :account_inactive}} =
               FinancialService.validate_account_active(inactive_account)
    end
  end

  describe "validate_sufficient_funds/2" do
    test "returns :ok for sufficient funds on DEBIT payment", %{
      payment: payment,
      account: account
    } do
      assert :ok = FinancialService.validate_sufficient_funds(payment, account)
    end

    test "returns error for insufficient funds on DEBIT payment", %{account: account} do
      large_payment =
        payment_fixture(account, %{amount: Decimal.new("1500.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :insufficient_funds}} =
               FinancialService.validate_sufficient_funds(large_payment, account)
    end

    test "returns :ok for CREDIT payment regardless of balance", %{account: account} do
      credit_payment =
        payment_fixture(account, %{amount: Decimal.new("10000.00"), direction: "CREDIT"})

      assert :ok = FinancialService.validate_sufficient_funds(credit_payment, account)
    end
  end

  describe "validate_daily_limits/2" do
    test "returns :ok when within daily limit", %{payment: payment, account: account} do
      assert :ok = FinancialService.validate_daily_limits(payment, account)
    end

    test "returns error when exceeding daily limit", %{account: account} do
      # Create payment that would exceed daily limit (1000.00 for CHECKING)
      large_payment =
        payment_fixture(account, %{amount: Decimal.new("1100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
               FinancialService.validate_daily_limits(large_payment, account)
    end
  end

  describe "validate_amount_limits/1" do
    test "returns :ok when within amount limit", %{payment: payment} do
      assert :ok = FinancialService.validate_amount_limits(payment)
    end

    test "returns error when exceeding amount limit", %{account: account} do
      large_payment =
        payment_fixture(account, %{amount: Decimal.new("15000.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :amount_exceeds_limit}} =
               FinancialService.validate_amount_limits(large_payment)
    end
  end

  describe "check_duplicate_transaction/1" do
    test "returns :ok when no duplicate found", %{payment: payment} do
      assert :ok = FinancialService.check_duplicate_transaction(payment)
    end

    test "returns error when duplicate found", %{account: account} do
      # Create two identical payments
      payment1 =
        payment_fixture(account, %{
          amount: Decimal.new("100.00"),
          direction: "DEBIT",
          description: "Duplicate test"
        })

      payment2 =
        payment_fixture(account, %{
          amount: Decimal.new("100.00"),
          direction: "DEBIT",
          description: "Duplicate test"
        })

      # Process first payment to make it completed
      payment1
      |> LedgerBankApi.Financial.Schemas.UserPayment.changeset(%{
        status: "COMPLETED",
        posted_at: DateTime.utc_now()
      })
      |> LedgerBankApi.Repo.update!()

      # Second payment should be detected as duplicate
      assert {:error, %LedgerBankApi.Core.Error{reason: :duplicate_transaction}} =
               FinancialService.check_duplicate_transaction(payment2)
    end
  end

  describe "validate_payment_status/1" do
    test "returns :ok for pending payment", %{payment: payment} do
      assert :ok = FinancialService.validate_payment_status(payment)
    end

    test "returns error for already processed payment", %{account: account} do
      completed_payment = payment_fixture(account, %{status: "COMPLETED"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :already_processed}} =
               FinancialService.validate_payment_status(completed_payment)
    end
  end

  describe "validate_account_balance/2" do
    test "returns :ok for sufficient balance", %{account: account} do
      assert :ok = FinancialService.validate_account_balance(account, Decimal.new("500.00"))
    end

    test "returns error for insufficient balance", %{account: account} do
      assert {:error, %LedgerBankApi.Core.Error{reason: :insufficient_funds}} =
               FinancialService.validate_account_balance(account, Decimal.new("1500.00"))
    end
  end

  describe "validate_user_account_access/2" do
    test "returns :ok for account owner", %{user: user, account: account} do
      assert :ok = FinancialService.validate_user_account_access(user, account)
    end

    test "returns error for non-owner", %{account: account} do
      other_user = user_fixture()

      assert {:error, %LedgerBankApi.Core.Error{reason: :unauthorized_access}} =
               FinancialService.validate_user_account_access(other_user, account)
    end
  end

  describe "validate_payment_amount_range/1" do
    test "returns :ok for valid amount" do
      assert :ok = FinancialService.validate_payment_amount_range(Decimal.new("100.00"))
    end

    test "returns error for amount too small" do
      assert {:error, %LedgerBankApi.Core.Error{reason: :amount_too_small}} =
               FinancialService.validate_payment_amount_range(Decimal.new("0.005"))
    end

    test "returns error for amount too large" do
      assert {:error, %LedgerBankApi.Core.Error{reason: :amount_exceeds_limit}} =
               FinancialService.validate_payment_amount_range(Decimal.new("15000.00"))
    end
  end

  describe "validate_account_not_frozen/1" do
    test "returns :ok for active account", %{account: account} do
      assert :ok = FinancialService.validate_account_not_frozen(account)
    end

    test "returns :ok for inactive account (not frozen)", %{login: login} do
      inactive_account = account_fixture(login, %{status: "INACTIVE"})

      assert :ok = FinancialService.validate_account_not_frozen(inactive_account)
    end

    test "returns :ok for closed account (not frozen)", %{login: login} do
      closed_account = account_fixture(login, %{status: "CLOSED"})

      assert :ok = FinancialService.validate_account_not_frozen(closed_account)
    end
  end

  describe "validate_payment_description/1" do
    test "returns :ok for valid description" do
      assert :ok = FinancialService.validate_payment_description("Valid payment description")
    end

    test "returns error for nil description" do
      assert {:error, %LedgerBankApi.Core.Error{reason: :description_required}} =
               FinancialService.validate_payment_description(nil)
    end

    test "returns error for empty description" do
      assert {:error, %LedgerBankApi.Core.Error{reason: :description_required}} =
               FinancialService.validate_payment_description("")
    end

    test "returns error for description too long" do
      long_description = String.duplicate("a", 256)

      assert {:error, %LedgerBankApi.Core.Error{reason: :description_too_long}} =
               FinancialService.validate_payment_description(long_description)
    end
  end

  describe "validate_payment_basic/3" do
    test "returns :ok for valid payment", %{payment: payment, account: account, user: user} do
      assert :ok = FinancialService.validate_payment_basic(payment, account, user)
    end

    test "returns first validation error found", %{account: account, user: user} do
      # Create payment with invalid status
      invalid_payment = payment_fixture(account, %{status: "COMPLETED"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :already_processed}} =
               FinancialService.validate_payment_basic(invalid_payment, account, user)
    end
  end

  describe "validate_payment_comprehensive/3" do
    test "returns :ok for valid payment", %{payment: payment, account: account, user: user} do
      assert :ok = FinancialService.validate_payment_comprehensive(payment, account, user)
    end

    test "returns error for duplicate transaction", %{account: account, user: user} do
      # Create two identical payments
      payment1 =
        payment_fixture(account, %{
          user_id: user.id,
          amount: Decimal.new("100.00"),
          direction: "DEBIT",
          description: "Duplicate test"
        })

      payment2 =
        payment_fixture(account, %{
          user_id: user.id,
          amount: Decimal.new("100.00"),
          direction: "DEBIT",
          description: "Duplicate test"
        })

      # Process first payment to make it completed
      payment1
      |> LedgerBankApi.Financial.Schemas.UserPayment.changeset(%{
        status: "COMPLETED",
        posted_at: DateTime.utc_now()
      })
      |> LedgerBankApi.Repo.update!()

      # Comprehensive validation should catch the duplicate
      assert {:error, %LedgerBankApi.Core.Error{reason: :duplicate_transaction}} =
               FinancialService.validate_payment_comprehensive(payment2, account, user)
    end
  end

  describe "check_account_financial_health/1" do
    test "returns health indicators for active account", %{account: account} do
      health = FinancialService.check_account_financial_health(account)

      assert health.account_id == account.id
      assert Decimal.eq?(health.balance, account.balance)
      assert health.status == account.status
      # CHECKING limit
      assert Decimal.eq?(health.daily_limit, Decimal.new("1000.00"))
      assert Decimal.eq?(health.daily_spent, Decimal.new("0"))
      assert Decimal.eq?(health.daily_remaining, Decimal.new("1000.00"))
      assert health.daily_utilization_percent == 0.0
      assert health.is_healthy == true
      assert health.can_make_payments == true
    end

    test "returns health indicators for inactive account", %{login: login} do
      inactive_account = account_fixture(login, %{status: "INACTIVE"})
      health = FinancialService.check_account_financial_health(inactive_account)

      assert health.is_healthy == false
      assert health.can_make_payments == false
    end
  end

  describe "check_user_financial_health/1" do
    test "returns aggregated health indicators" do
      # Create a fresh user to avoid interference from setup
      user = user_fixture()
      login = login_fixture(user)

      # Create multiple accounts
      _account1 = account_fixture(login, %{balance: Decimal.new("1000.00"), status: "ACTIVE"})
      _account2 = account_fixture(login, %{balance: Decimal.new("500.00"), status: "ACTIVE"})
      _account3 = account_fixture(login, %{balance: Decimal.new("0.00"), status: "CLOSED"})

      health = FinancialService.check_user_financial_health(user.id)

      assert health.user_id == user.id
      assert Decimal.eq?(health.total_balance, Decimal.new("1500.00"))
      assert health.total_accounts == 3
      assert health.active_accounts == 2
      assert health.frozen_accounts == 0
      assert health.suspended_accounts == 0
      assert health.is_healthy == true
      assert health.can_make_payments == true
    end
  end

  describe "daily limits for different account types" do
    test "CHECKING account has 1000.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)

      account =
        account_fixture(login, %{account_type: "CHECKING", balance: Decimal.new("2000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("1100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
               FinancialService.validate_daily_limits(payment, account)
    end

    test "SAVINGS account has 500.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)

      account =
        account_fixture(login, %{account_type: "SAVINGS", balance: Decimal.new("1000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("600.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
               FinancialService.validate_daily_limits(payment, account)
    end

    test "CREDIT account has 2000.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{account_type: "CREDIT", balance: Decimal.new("3000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("2100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
               FinancialService.validate_daily_limits(payment, account)
    end

    test "INVESTMENT account has 5000.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)

      account =
        account_fixture(login, %{account_type: "INVESTMENT", balance: Decimal.new("6000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("5100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
               FinancialService.validate_daily_limits(payment, account)
    end
  end
end

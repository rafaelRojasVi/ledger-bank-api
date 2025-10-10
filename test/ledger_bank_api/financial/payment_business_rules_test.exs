defmodule LedgerBankApi.Financial.PaymentBusinessRulesTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Financial.FinancialService
  import LedgerBankApi.BankingFixtures
  import LedgerBankApi.UsersFixtures

  describe "payment processing with business rules" do
    setup do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("1000.00"), account_type: "CHECKING"})
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      %{user: user, login: login, account: account, payment: payment}
    end

    test "processes payment successfully when all business rules pass", %{payment: payment} do
      assert {:ok, updated_payment} = FinancialService.process_payment(payment.id)
      assert updated_payment.status == "COMPLETED"
      assert updated_payment.posted_at != nil
    end

    test "returns error when account is inactive", %{user: user, login: login} do
      # Create inactive account
      inactive_account = account_fixture(login, %{status: "INACTIVE"})
      payment = payment_fixture(inactive_account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :account_inactive}} =
        FinancialService.process_payment(payment.id)
    end

    test "returns error when insufficient funds for DEBIT payment", %{account: account} do
      # Create payment that exceeds account balance
      payment = payment_fixture(account, %{
        amount: Decimal.new("1500.00"),  # More than account balance of 1000.00
        direction: "DEBIT"
      })

      assert {:error, %LedgerBankApi.Core.Error{reason: :insufficient_funds}} =
        FinancialService.process_payment(payment.id)
    end

    test "allows CREDIT payment even with zero balance", %{account: account} do
      # Set account balance to zero
      account
      |> LedgerBankApi.Financial.Schemas.UserBankAccount.balance_changeset(%{balance: Decimal.new("0")})
      |> LedgerBankApi.Repo.update!()

      payment = payment_fixture(account, %{amount: Decimal.new("100.00"), direction: "CREDIT"})

      assert {:ok, updated_payment} = FinancialService.process_payment(payment.id)
      assert updated_payment.status == "COMPLETED"
    end

    test "returns error when daily limit exceeded", %{account: account} do
      # Increase account balance to ensure sufficient funds for both payments
      account
      |> LedgerBankApi.Financial.Schemas.UserBankAccount.balance_changeset(%{balance: Decimal.new("2000.00")})
      |> LedgerBankApi.Repo.update!()

      # Create multiple payments that exceed daily limit (1000.00 for CHECKING)
      payment1 = payment_fixture(account, %{amount: Decimal.new("600.00"), direction: "DEBIT"})
      payment2 = payment_fixture(account, %{amount: Decimal.new("500.00"), direction: "DEBIT"})

      # Process first payment successfully
      assert {:ok, _} = FinancialService.process_payment(payment1.id)

      # Second payment should fail due to daily limit (600 + 500 = 1100 > 1000)
      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
        FinancialService.process_payment(payment2.id)
    end

    test "returns error when single transaction amount exceeds limit", %{account: account} do
      # Create payment that exceeds single transaction limit (10000.00)
      # But not so much that it fails insufficient funds first
      payment = payment_fixture(account, %{
        amount: Decimal.new("15000.00"),  # More than single transaction limit
        direction: "DEBIT"
      })

      # This will fail with insufficient funds because amount limit check happens after
      # Let's test with a smaller amount that exceeds limit but not account balance
      # First, let's set a higher account balance
      account
      |> LedgerBankApi.Financial.Schemas.UserBankAccount.balance_changeset(%{balance: Decimal.new("20000.00")})
      |> LedgerBankApi.Repo.update!()

      assert {:error, %LedgerBankApi.Core.Error{reason: :amount_exceeds_limit}} =
        FinancialService.process_payment(payment.id)
    end

    test "returns error when duplicate transaction detected", %{account: account} do
      # Create two identical payments
      payment1 = payment_fixture(account, %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        description: "Duplicate test payment"
      })
      payment2 = payment_fixture(account, %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        description: "Duplicate test payment"
      })

      # Process first payment successfully
      assert {:ok, _} = FinancialService.process_payment(payment1.id)

      # Second payment should fail due to duplicate detection
      assert {:error, %LedgerBankApi.Core.Error{reason: :duplicate_transaction}} =
        FinancialService.process_payment(payment2.id)
    end

    test "updates account balance correctly for DEBIT payment", %{account: account, payment: payment} do
      initial_balance = account.balance

      assert {:ok, _} = FinancialService.process_payment(payment.id)

      # Reload account to get updated balance
      updated_account = LedgerBankApi.Repo.get(LedgerBankApi.Financial.Schemas.UserBankAccount, account.id)
      expected_balance = Decimal.sub(initial_balance, payment.amount)

      assert Decimal.eq?(updated_account.balance, expected_balance)
    end

    test "updates account balance correctly for CREDIT payment", %{account: account} do
      initial_balance = account.balance
      payment = payment_fixture(account, %{amount: Decimal.new("200.00"), direction: "CREDIT"})

      assert {:ok, _} = FinancialService.process_payment(payment.id)

      # Reload account to get updated balance
      updated_account = LedgerBankApi.Repo.get(LedgerBankApi.Financial.Schemas.UserBankAccount, account.id)
      expected_balance = Decimal.add(initial_balance, payment.amount)

      assert Decimal.eq?(updated_account.balance, expected_balance)
    end

    test "creates transaction record when payment is processed", %{payment: payment} do
      assert {:ok, _} = FinancialService.process_payment(payment.id)

      # Check that transaction record was created
      transaction = LedgerBankApi.Repo.one(
        from t in LedgerBankApi.Financial.Schemas.Transaction,
        where: t.amount == ^payment.amount,
        where: t.direction == ^payment.direction,
        where: t.description == ^payment.description,
        where: t.user_id == ^payment.user_id
      )

      assert transaction != nil
      assert Decimal.eq?(transaction.amount, payment.amount)
      assert transaction.direction == payment.direction
      assert transaction.description == payment.description
    end
  end

  describe "payment creation with business rules" do
    setup do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("1000.00"), account_type: "CHECKING"})

      %{user: user, login: login, account: account}
    end

    test "creates payment successfully when business rules pass", %{user: user, account: account} do
      attrs = %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        payment_type: "PAYMENT",
        description: "Test payment",
        user_bank_account_id: account.id,
        user_id: user.id
      }

      assert {:ok, payment} = FinancialService.create_user_payment(attrs)
      assert payment.amount == Decimal.new("100.00")
      assert payment.direction == "DEBIT"
      assert payment.status == "PENDING"
    end

    test "returns error when account is inactive during creation", %{user: user} do
      # Create inactive account
      login = login_fixture(user)
      inactive_account = account_fixture(login, %{status: "INACTIVE"})

      attrs = %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        payment_type: "PAYMENT",
        description: "Test payment",
        user_bank_account_id: inactive_account.id,
        user_id: user.id
      }

      assert {:error, %LedgerBankApi.Core.Error{reason: :account_inactive}} =
        FinancialService.create_user_payment(attrs)
    end

    test "returns error when amount exceeds single transaction limit during creation", %{user: user, account: account} do
      attrs = %{
        amount: Decimal.new("15000.00"),  # More than single transaction limit
        direction: "DEBIT",
        payment_type: "PAYMENT",
        description: "Test payment",
        user_bank_account_id: account.id,
        user_id: user.id
      }

      assert {:error, %LedgerBankApi.Core.Error{reason: :amount_exceeds_limit}} =
        FinancialService.create_user_payment(attrs)
    end
  end

  describe "daily limits for different account types" do
    test "CHECKING account has 1000.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{account_type: "CHECKING", balance: Decimal.new("2000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("1100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
        FinancialService.process_payment(payment.id)
    end

    test "SAVINGS account has 500.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{account_type: "SAVINGS", balance: Decimal.new("1000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("600.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
        FinancialService.process_payment(payment.id)
    end

    test "CREDIT account has 2000.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{account_type: "CREDIT", balance: Decimal.new("3000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("2100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
        FinancialService.process_payment(payment.id)
    end

    test "INVESTMENT account has 5000.00 daily limit" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{account_type: "INVESTMENT", balance: Decimal.new("6000.00")})

      # Create payment that would exceed daily limit
      payment = payment_fixture(account, %{amount: Decimal.new("5100.00"), direction: "DEBIT"})

      assert {:error, %LedgerBankApi.Core.Error{reason: :daily_limit_exceeded}} =
        FinancialService.process_payment(payment.id)
    end
  end

  describe "duplicate transaction detection" do
    setup do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("1000.00"), account_type: "CHECKING"})

      %{user: user, login: login, account: account}
    end

    test "detects duplicates within 5 minute window", %{account: account} do
      # Create two identical payments
      payment1 = payment_fixture(account, %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        description: "Duplicate test"
      })
      payment2 = payment_fixture(account, %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        description: "Duplicate test"
      })

      # Process first payment
      assert {:ok, _} = FinancialService.process_payment(payment1.id)

      # Second payment should be detected as duplicate
      assert {:error, %LedgerBankApi.Core.Error{reason: :duplicate_transaction}} =
        FinancialService.process_payment(payment2.id)
    end

    test "allows similar payments with different amounts", %{account: account} do
      payment1 = payment_fixture(account, %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        description: "Test payment"
      })
      payment2 = payment_fixture(account, %{
        amount: Decimal.new("200.00"),  # Different amount
        direction: "DEBIT",
        description: "Test payment"
      })

      # Both payments should process successfully
      assert {:ok, _} = FinancialService.process_payment(payment1.id)
      assert {:ok, _} = FinancialService.process_payment(payment2.id)
    end

    test "allows similar payments with different descriptions", %{account: account} do
      payment1 = payment_fixture(account, %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        description: "Payment 1"
      })
      payment2 = payment_fixture(account, %{
        amount: Decimal.new("100.00"),
        direction: "DEBIT",
        description: "Payment 2"  # Different description
      })

      # Both payments should process successfully
      assert {:ok, _} = FinancialService.process_payment(payment1.id)
      assert {:ok, _} = FinancialService.process_payment(payment2.id)
    end
  end
end

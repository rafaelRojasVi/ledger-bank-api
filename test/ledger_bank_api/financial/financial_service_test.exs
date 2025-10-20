defmodule LedgerBankApi.Financial.FinancialServiceTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Financial.FinancialService
  import LedgerBankApi.BankingFixtures
  import LedgerBankApi.UsersFixtures

  describe "get_bank/1" do
    test "returns bank when found" do
      bank = bank_fixture()

      assert {:ok, retrieved_bank} = FinancialService.get_bank(bank.id)
      assert retrieved_bank.id == bank.id
    end

    test "returns error when bank not found" do
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.get_bank(999)
    end
  end

  describe "get_user_bank_account/1" do
    test "returns account when found" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)

      assert {:ok, retrieved_account} = FinancialService.get_user_bank_account(account.id)
      assert retrieved_account.id == account.id
    end

    test "returns error when account not found" do
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.get_user_bank_account(999)
    end
  end

  describe "get_user_payment/1" do
    test "returns payment when found" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account)

      assert {:ok, retrieved_payment} = FinancialService.get_user_payment(payment.id)
      assert retrieved_payment.id == payment.id
    end

    test "returns error when payment not found" do
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.get_user_payment(999)
    end
  end

  describe "create_user_payment/1" do
    test "creates payment with valid attributes" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)

      attrs = %{
        amount: Decimal.new("100.50"),
        direction: "CREDIT",
        payment_type: "TRANSFER",
        description: "Test payment",
        user_bank_account_id: account.id,
        user_id: user.id
      }

      assert {:ok, payment} = FinancialService.create_user_payment(attrs)
      assert payment.amount == Decimal.new("100.50")
      assert payment.direction == "CREDIT"
      assert payment.payment_type == "TRANSFER"
      assert payment.description == "Test payment"
      assert payment.user_bank_account_id == account.id
      assert payment.user_id == user.id
      assert payment.status == "PENDING"
    end

    test "returns error with invalid attributes" do
      attrs = %{
        # Invalid negative amount
        amount: Decimal.new("-100.50"),
        # Invalid direction
        direction: "INVALID",
        payment_type: "TRANSFER",
        description: "Test payment",
        # Non-existent account
        user_bank_account_id: 999,
        user_id: 999
      }

      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.create_user_payment(attrs)
    end
  end

  describe "process_payment/1" do
    test "processes pending payment successfully" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account, %{status: "PENDING"})

      assert {:ok, updated_payment} = FinancialService.process_payment(payment.id)
      assert updated_payment.status == "COMPLETED"
      assert updated_payment.posted_at != nil
    end

    test "returns error when payment not found" do
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.process_payment(999)
    end

    test "returns error when payment already processed" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account, %{status: "COMPLETED"})

      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.process_payment(payment.id)
    end

    test "returns error when payment failed" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account, %{status: "FAILED"})

      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.process_payment(payment.id)
    end
  end

  describe "list_user_payments/2" do
    test "lists payments for user" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment1 = payment_fixture(account, %{user_id: user.id})
      payment2 = payment_fixture(account, %{user_id: user.id})

      # Create payment for different user
      other_user = user_fixture()
      other_login = login_fixture(other_user)
      other_account = account_fixture(other_login)
      _other_payment = payment_fixture(other_account, %{user_id: other_user.id})

      {payments, _pagination} = FinancialService.list_user_payments(user.id)

      assert length(payments) == 2
      payment_ids = Enum.map(payments, & &1.id)
      assert payment1.id in payment_ids
      assert payment2.id in payment_ids
    end

    test "returns empty list when user has no payments" do
      user = user_fixture()

      {payments, _pagination} = FinancialService.list_user_payments(user.id)
      assert payments == []
    end

    test "applies pagination options" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)

      # Create 5 payments
      for i <- 1..5 do
        payment_fixture(account, %{user_id: user.id, description: "Payment #{i}"})
      end

      opts = [pagination: %{page: 1, page_size: 2}]
      {payments, _pagination} = FinancialService.list_user_payments(user.id, opts)

      assert length(payments) == 2
    end

    test "applies sorting options" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)

      _payment1 = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100")})
      _payment2 = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("200")})

      opts = [sort: %{field: :amount, direction: :desc}]
      {payments, _pagination} = FinancialService.list_user_payments(user.id, opts)

      assert length(payments) == 2
      assert hd(payments).amount == Decimal.new("200")
      assert List.last(payments).amount == Decimal.new("100")
    end
  end

  describe "list_user_bank_accounts/1" do
    test "lists accounts for user" do
      user = user_fixture()
      login1 = login_fixture(user)
      account1 = account_fixture(login1)
      login2 = login_fixture(user)
      account2 = account_fixture(login2)

      # Create account for different user
      other_user = user_fixture()
      other_login = login_fixture(other_user)
      _other_account = account_fixture(other_login)

      accounts = FinancialService.list_user_bank_accounts(user.id)

      assert length(accounts) == 2
      account_ids = Enum.map(accounts, & &1.id)
      assert account1.id in account_ids
      assert account2.id in account_ids
    end

    test "returns empty list when user has no accounts" do
      user = user_fixture()

      accounts = FinancialService.list_user_bank_accounts(user.id)
      assert accounts == []
    end
  end

  describe "list_transactions/2" do
    test "lists transactions for account" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      transaction1 = transaction_fixture(account)
      transaction2 = transaction_fixture(account)

      # Create transaction for different account
      other_user = user_fixture()
      other_login = login_fixture(other_user)
      other_account = account_fixture(other_login)
      _other_transaction = transaction_fixture(other_account)

      transactions = FinancialService.list_transactions(account.id)

      assert length(transactions) == 2
      transaction_ids = Enum.map(transactions, & &1.id)
      assert transaction1.id in transaction_ids
      assert transaction2.id in transaction_ids
    end

    test "returns empty list when account has no transactions" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)

      transactions = FinancialService.list_transactions(account.id)
      assert transactions == []
    end

    test "applies filters" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      transaction1 = transaction_fixture(account, %{direction: "CREDIT"})
      _transaction2 = transaction_fixture(account, %{direction: "DEBIT"})

      opts = [filters: %{direction: "CREDIT"}]
      transactions = FinancialService.list_transactions(account.id, opts)

      assert length(transactions) == 1
      assert hd(transactions).id == transaction1.id
    end
  end

  describe "sync_login/1" do
    test "syncs login successfully" do
      user = user_fixture()
      login = login_fixture(user)

      assert {:ok, result} = FinancialService.sync_login(login.id)
      assert result.status == "synced"
      assert result.login_id == login.id
      assert result.synced_at != nil
    end

    test "returns error when login not found" do
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.sync_login(999)
    end
  end

  describe "service behavior implementation" do
    test "implements service_name/0" do
      assert FinancialService.service_name() == "financial_service"
    end

    test "uses ServiceBehavior pattern consistently" do
      # Test that all public functions use ServiceBehavior.with_standard_error_handling
      # This is more of an integration test to ensure the pattern is followed

      # Test get_bank with non-existent ID
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.get_bank(999)

      # Test get_user_bank_account with non-existent ID
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.get_user_bank_account(999)

      # Test get_user_payment with non-existent ID
      assert {:error, %LedgerBankApi.Core.Error{}} = FinancialService.get_user_payment(999)
    end
  end
end

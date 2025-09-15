defmodule LedgerBankApi.Banking.Schemas.UserBankAccountTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Schemas.UserBankAccount
  import Decimal

  describe "changeset/2" do
    test "valid changeset for checking account" do
      attrs = %{
        user_bank_login_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        currency: "USD",
        account_type: "CHECKING",
        balance: new("1000.00"),
        last_four: "1234",
        account_name: "My Checking Account"
      }

      changeset = UserBankAccount.changeset(%UserBankAccount{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset for credit account with negative balance" do
      attrs = %{
        user_bank_login_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        currency: "USD",
        account_type: "CREDIT",
        balance: new("-500.00"),  # Credit accounts can have negative balances
        last_four: "5678",
        account_name: "My Credit Card"
      }

      changeset = UserBankAccount.changeset(%UserBankAccount{}, attrs)

      assert changeset.valid?
    end

    test "invalid changeset for checking account with negative balance" do
      attrs = %{
        user_bank_login_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        currency: "USD",
        account_type: "CHECKING",
        balance: new("-100.00"),  # Checking accounts cannot have negative balances
        last_four: "1234",
        account_name: "My Checking Account"
      }

      changeset = UserBankAccount.changeset(%UserBankAccount{}, attrs)

      refute changeset.valid?
      assert "cannot be negative for CHECKING accounts" in errors_on(changeset).balance
    end

    test "invalid changeset with invalid currency" do
      attrs = %{
        user_bank_login_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        currency: "INVALID",
        account_type: "CHECKING"
      }

      changeset = UserBankAccount.changeset(%UserBankAccount{}, attrs)

      refute changeset.valid?
      assert "must be a valid 3-letter currency code (e.g., USD, EUR)" in errors_on(changeset).currency
    end

    test "invalid changeset with invalid last_four" do
      attrs = %{
        user_bank_login_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        currency: "USD",
        account_type: "CHECKING",
        last_four: "123"  # Must be exactly 4 digits
      }

      changeset = UserBankAccount.changeset(%UserBankAccount{}, attrs)

      refute changeset.valid?
      assert "must be exactly 4 digits" in errors_on(changeset).last_four
    end
  end

  describe "has_sufficient_balance?/2" do
    test "returns true for credit account regardless of balance" do
      account = %UserBankAccount{
        balance: new("-1000.00"),
        account_type: "CREDIT"
      }

      assert UserBankAccount.has_sufficient_balance?(account, new("500.00"))
    end

    test "returns true for checking account with sufficient balance" do
      account = %UserBankAccount{
        balance: new("1000.00"),
        account_type: "CHECKING"
      }

      assert UserBankAccount.has_sufficient_balance?(account, new("500.00"))
    end

    test "returns false for checking account with insufficient balance" do
      account = %UserBankAccount{
        balance: new("100.00"),
        account_type: "CHECKING"
      }

      refute UserBankAccount.has_sufficient_balance?(account, new("500.00"))
    end
  end

  describe "is_credit_account?/1" do
    test "returns true for credit account" do
      account = %UserBankAccount{account_type: "CREDIT"}
      assert UserBankAccount.is_credit_account?(account)
    end

    test "returns false for checking account" do
      account = %UserBankAccount{account_type: "CHECKING"}
      refute UserBankAccount.is_credit_account?(account)
    end
  end

  describe "needs_sync?/1" do
    test "returns true when last_sync_at is nil" do
      account = %UserBankAccount{last_sync_at: nil}
      assert UserBankAccount.needs_sync?(account)
    end

    test "returns true when last sync was more than 1 hour ago" do
      old_time = DateTime.add(DateTime.utc_now(), -7200, :second)  # 2 hours ago
      account = %UserBankAccount{last_sync_at: old_time}
      assert UserBankAccount.needs_sync?(account)
    end

    test "returns false when last sync was less than 1 hour ago" do
      recent_time = DateTime.add(DateTime.utc_now(), -1800, :second)  # 30 minutes ago
      account = %UserBankAccount{last_sync_at: recent_time}
      refute UserBankAccount.needs_sync?(account)
    end
  end
end

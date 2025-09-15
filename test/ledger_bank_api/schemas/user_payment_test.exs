defmodule LedgerBankApi.Banking.Schemas.UserPaymentTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Schemas.UserPayment
  import Decimal

  describe "changeset/2" do
    test "valid changeset for debit payment" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("50.00"),
        direction: "DEBIT",
        description: "Coffee purchase",
        payment_type: "PAYMENT"
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset for credit payment" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("100.00"),
        direction: "CREDIT",
        description: "Salary deposit",
        payment_type: "DEPOSIT"
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      assert changeset.valid?
    end

    test "invalid changeset with negative amount" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("-10.00"),
        direction: "DEBIT",
        payment_type: "PAYMENT"
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      refute changeset.valid?
      assert "cannot be negative" in errors_on(changeset).amount
    end

    test "invalid changeset with invalid direction" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("50.00"),
        direction: "INVALID",
        payment_type: "PAYMENT"
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).direction
    end

    test "invalid changeset with invalid payment type" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("50.00"),
        direction: "DEBIT",
        payment_type: "INVALID"
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      refute changeset.valid?
      assert "must be TRANSFER, PAYMENT, DEPOSIT, or WITHDRAWAL" in errors_on(changeset).payment_type
    end

    test "invalid changeset with invalid status" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("50.00"),
        direction: "DEBIT",
        payment_type: "PAYMENT",
        status: "INVALID"
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      refute changeset.valid?
      assert "must be PENDING, COMPLETED, FAILED, or CANCELLED" in errors_on(changeset).status
    end

    test "invalid changeset with description too long" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("50.00"),
        direction: "DEBIT",
        payment_type: "PAYMENT",
        description: String.duplicate("A", 501)  # Too long
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).description
    end

    test "invalid changeset with posted_at in future" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("50.00"),
        direction: "DEBIT",
        payment_type: "PAYMENT",
        posted_at: future_time
      }

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      refute changeset.valid?
      assert "cannot be in the future" in errors_on(changeset).posted_at
    end

    test "invalid changeset with missing required fields" do
      attrs = %{}

      changeset = UserPayment.changeset(%UserPayment{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset).user_bank_account_id
      assert errors_on(changeset).user_id
      assert errors_on(changeset).amount
      assert errors_on(changeset).direction
      assert errors_on(changeset).payment_type
    end

    test "valid changeset with all payment types" do
      payment_types = ["TRANSFER", "PAYMENT", "DEPOSIT", "WITHDRAWAL"]

      for payment_type <- payment_types do
        attrs = %{
          user_bank_account_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate(),
          amount: new("50.00"),
          direction: "DEBIT",
          payment_type: payment_type
        }

        changeset = UserPayment.changeset(%UserPayment{}, attrs)
        assert changeset.valid?, "Payment type #{payment_type} should be valid"
      end
    end

    test "valid changeset with all statuses" do
      statuses = ["PENDING", "COMPLETED", "FAILED", "CANCELLED"]

      for status <- statuses do
        attrs = %{
          user_bank_account_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate(),
          amount: new("50.00"),
          direction: "DEBIT",
          payment_type: "PAYMENT",
          status: status
        }

        changeset = UserPayment.changeset(%UserPayment{}, attrs)
        assert changeset.valid?, "Status #{status} should be valid"
      end
    end
  end

  describe "base_changeset/2" do
    test "valid base changeset" do
      attrs = %{
        user_bank_account_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        amount: new("50.00"),
        direction: "DEBIT",
        payment_type: "PAYMENT"
      }

      changeset = UserPayment.base_changeset(%UserPayment{}, attrs)

      assert changeset.valid?
    end
  end
end

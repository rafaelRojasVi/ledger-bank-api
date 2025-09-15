defmodule LedgerBankApi.Banking.Schemas.TransactionTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Schemas.Transaction
  import Decimal

  describe "changeset/2" do
    test "valid changeset for debit transaction" do
      attrs = %{
        amount: new("25.00"),
        posted_at: DateTime.utc_now(),
        description: "Coffee purchase",
        account_id: Ecto.UUID.generate(),
        direction: "DEBIT",
        user_id: Ecto.UUID.generate()
      }

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset for credit transaction" do
      attrs = %{
        amount: new("100.00"),
        posted_at: DateTime.utc_now(),
        description: "Salary deposit",
        account_id: Ecto.UUID.generate(),
        direction: "CREDIT",
        user_id: Ecto.UUID.generate()
      }

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      assert changeset.valid?
    end

    test "invalid changeset with negative amount" do
      attrs = %{
        amount: new("-10.00"),
        posted_at: DateTime.utc_now(),
        description: "Test transaction",
        account_id: Ecto.UUID.generate(),
        direction: "DEBIT",
        user_id: Ecto.UUID.generate()
      }

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "cannot be negative" in errors_on(changeset).amount
    end

    test "invalid changeset with invalid direction" do
      attrs = %{
        amount: new("50.00"),
        posted_at: DateTime.utc_now(),
        description: "Test transaction",
        account_id: Ecto.UUID.generate(),
        direction: "INVALID",
        user_id: Ecto.UUID.generate()
      }

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).direction
    end

    test "invalid changeset with description too long" do
      attrs = %{
        amount: new("50.00"),
        posted_at: DateTime.utc_now(),
        description: String.duplicate("A", 501),  # Too long
        account_id: Ecto.UUID.generate(),
        direction: "DEBIT",
        user_id: Ecto.UUID.generate()
      }

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).description
    end

    test "invalid changeset with posted_at in future" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      attrs = %{
        amount: new("50.00"),
        posted_at: future_time,
        description: "Test transaction",
        account_id: Ecto.UUID.generate(),
        direction: "DEBIT",
        user_id: Ecto.UUID.generate()
      }

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert "cannot be in the future" in errors_on(changeset).posted_at
    end

    test "invalid changeset with missing required fields" do
      attrs = %{}

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset).amount
      assert errors_on(changeset).posted_at
      assert errors_on(changeset).description
      assert errors_on(changeset).account_id
      assert errors_on(changeset).direction
      assert errors_on(changeset).user_id
    end

    test "valid changeset with both directions" do
      directions = ["CREDIT", "DEBIT"]

      for direction <- directions do
        attrs = %{
          amount: new("50.00"),
          posted_at: DateTime.utc_now(),
          description: "Test transaction",
          account_id: Ecto.UUID.generate(),
          direction: direction,
          user_id: Ecto.UUID.generate()
        }

        changeset = Transaction.base_changeset(%Transaction{}, attrs)
        assert changeset.valid?, "Direction #{direction} should be valid"
      end
    end
  end

  describe "base_changeset/2" do
    test "valid base changeset" do
      attrs = %{
        amount: new("50.00"),
        posted_at: DateTime.utc_now(),
        description: "Test transaction",
        account_id: Ecto.UUID.generate(),
        direction: "DEBIT",
        user_id: Ecto.UUID.generate()
      }

      changeset = Transaction.base_changeset(%Transaction{}, attrs)

      assert changeset.valid?
    end
  end
end

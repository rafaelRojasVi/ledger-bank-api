defmodule LedgerBankApi.Financial.NormalizeTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Financial.Normalize

  describe "payment_attrs/1" do
    test "normalizes payment attributes correctly" do
      attrs = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "  Test payment  ",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000",
        "user_id" => "456e7890-e89b-12d3-a456-426614174000"
      }

      result = Normalize.payment_attrs(attrs)

      assert result["amount"] == Decimal.new("100.50")
      assert result["direction"] == "CREDIT"
      assert result["payment_type"] == "TRANSFER"
      assert result["description"] == "Test payment"
      assert result["user_bank_account_id"] == "123e4567-e89b-12d3-a456-426614174000"
      assert result["user_id"] == "456e7890-e89b-12d3-a456-426614174000"
      assert result["status"] == "PENDING"
    end

    test "handles atom keys" do
      attrs = %{
        amount: "100.50",
        direction: "credit",
        payment_type: "transfer",
        description: "Test payment",
        user_bank_account_id: "123e4567-e89b-12d3-a456-426614174000"
      }

      result = Normalize.payment_attrs(attrs)

      assert result["amount"] == Decimal.new("100.50")
      assert result["direction"] == "CREDIT"
      assert result["payment_type"] == "TRANSFER"
    end

    test "handles nil input" do
      assert Normalize.payment_attrs(nil) == %{}
    end

    test "handles invalid input" do
      assert Normalize.payment_attrs("invalid") == %{}
    end

    test "filters out invalid fields" do
      attrs = %{
        "amount" => "100.50",
        "direction" => "credit",
        "invalid_field" => "should be removed",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      result = Normalize.payment_attrs(attrs)

      refute Map.has_key?(result, "invalid_field")
      assert result["amount"] == Decimal.new("100.50")
    end
  end

  describe "bank_account_attrs/1" do
    test "normalizes bank account attributes correctly" do
      attrs = %{
        "currency" => "usd",
        "account_type" => "checking",
        "account_name" => "  My Checking Account  ",
        "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000",
        "user_id" => "456e7890-e89b-12d3-a456-426614174000",
        "last_four" => "1234",
        "external_account_id" => "ext_123"
      }

      result = Normalize.bank_account_attrs(attrs)

      assert result["currency"] == "USD"
      assert result["account_type"] == "CHECKING"
      assert result["account_name"] == "My Checking Account"
      assert result["user_bank_login_id"] == "123e4567-e89b-12d3-a456-426614174000"
      assert result["user_id"] == "456e7890-e89b-12d3-a456-426614174000"
      assert result["last_four"] == "1234"
      assert result["external_account_id"] == "ext_123"
      assert result["status"] == "ACTIVE"
      assert result["balance"] == Decimal.new(0)
    end

    test "handles nil input" do
      assert Normalize.bank_account_attrs(nil) == %{}
    end
  end

  describe "transaction_attrs/1" do
    test "normalizes transaction attributes correctly" do
      attrs = %{
        "amount" => "50.25",
        "direction" => "debit",
        "description" => "  Purchase  ",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000",
        "external_transaction_id" => "ext_txn_123",
        "posted_at" => "2023-01-01T12:00:00Z"
      }

      result = Normalize.transaction_attrs(attrs)

      assert result["amount"] == Decimal.new("50.25")
      assert result["direction"] == "DEBIT"
      assert result["description"] == "Purchase"
      assert result["user_bank_account_id"] == "123e4567-e89b-12d3-a456-426614174000"
      assert result["external_transaction_id"] == "ext_txn_123"
      assert %DateTime{} = result["posted_at"]
    end

    test "handles nil input" do
      assert Normalize.transaction_attrs(nil) == %{}
    end
  end

  describe "payment_update_attrs/1" do
    test "normalizes payment update attributes correctly" do
      attrs = %{
        "description" => "  Updated description  ",
        "status" => "pending"
      }

      result = Normalize.payment_update_attrs(attrs)

      assert result["description"] == "Updated description"
      assert result["status"] == "PENDING"
    end

    test "filters out non-updatable fields" do
      attrs = %{
        "description" => "Updated description",
        # Should be filtered out
        "amount" => "100.50",
        # Should be filtered out
        "user_id" => "123"
      }

      result = Normalize.payment_update_attrs(attrs)

      assert result["description"] == "Updated description"
      refute Map.has_key?(result, "amount")
      refute Map.has_key?(result, "user_id")
    end
  end

  describe "bank_account_update_attrs/1" do
    test "normalizes bank account update attributes correctly" do
      attrs = %{
        "account_name" => "  Updated Account Name  ",
        "status" => "inactive",
        "balance" => "1000.00",
        "last_sync_at" => "2023-01-01T12:00:00Z"
      }

      result = Normalize.bank_account_update_attrs(attrs)

      assert result["account_name"] == "Updated Account Name"
      assert result["status"] == "INACTIVE"
      assert result["balance"] == Decimal.new("1000.00")
      assert %DateTime{} = result["last_sync_at"]
    end

    test "filters out non-updatable fields" do
      attrs = %{
        "account_name" => "Updated Name",
        # Should be filtered out
        "currency" => "EUR",
        # Should be filtered out
        "user_id" => "123"
      }

      result = Normalize.bank_account_update_attrs(attrs)

      assert result["account_name"] == "Updated Name"
      refute Map.has_key?(result, "currency")
      refute Map.has_key?(result, "user_id")
    end
  end

  describe "amount normalization" do
    test "handles string amounts" do
      attrs = %{"amount" => "100.50"}
      result = Normalize.payment_attrs(attrs)
      assert result["amount"] == Decimal.new("100.50")
    end

    test "handles float amounts" do
      attrs = %{"amount" => 100.50}
      result = Normalize.payment_attrs(attrs)
      assert result["amount"] == Decimal.from_float(100.50)
    end

    test "handles invalid amounts" do
      attrs = %{"amount" => "invalid"}
      result = Normalize.payment_attrs(attrs)
      # Should remain unchanged
      assert result["amount"] == "invalid"
    end
  end

  describe "direction normalization" do
    test "normalizes credit direction" do
      attrs = %{"direction" => "credit"}
      result = Normalize.payment_attrs(attrs)
      assert result["direction"] == "CREDIT"
    end

    test "normalizes debit direction" do
      attrs = %{"direction" => "debit"}
      result = Normalize.payment_attrs(attrs)
      assert result["direction"] == "DEBIT"
    end

    test "handles invalid direction" do
      attrs = %{"direction" => "invalid"}
      result = Normalize.payment_attrs(attrs)
      # Should remain unchanged
      assert result["direction"] == "invalid"
    end
  end

  describe "currency normalization" do
    test "normalizes currency codes" do
      attrs = %{"currency" => "usd"}
      result = Normalize.bank_account_attrs(attrs)
      assert result["currency"] == "USD"
    end

    test "handles invalid currency format" do
      attrs = %{"currency" => "invalid"}
      result = Normalize.bank_account_attrs(attrs)
      # Should remain unchanged
      assert result["currency"] == "invalid"
    end
  end

  describe "description normalization" do
    test "trims whitespace from descriptions" do
      attrs = %{"description" => "  Test description  "}
      result = Normalize.payment_attrs(attrs)
      assert result["description"] == "Test description"
    end

    test "handles long descriptions" do
      long_desc = String.duplicate("a", 300)
      attrs = %{"description" => long_desc}
      result = Normalize.payment_attrs(attrs)
      # Should remain unchanged
      assert result["description"] == long_desc
    end
  end

  describe "UUID normalization" do
    test "validates UUID format" do
      attrs = %{"user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"}
      result = Normalize.payment_attrs(attrs)
      assert result["user_bank_account_id"] == "123e4567-e89b-12d3-a456-426614174000"
    end

    test "handles invalid UUID format" do
      attrs = %{"user_bank_account_id" => "invalid-uuid"}
      result = Normalize.payment_attrs(attrs)
      # Should remain unchanged
      assert result["user_bank_account_id"] == "invalid-uuid"
    end
  end

  describe "datetime normalization" do
    test "normalizes ISO8601 datetime strings" do
      attrs = %{"posted_at" => "2023-01-01T12:00:00Z"}
      result = Normalize.transaction_attrs(attrs)
      assert %DateTime{} = result["posted_at"]
    end

    test "handles invalid datetime strings" do
      attrs = %{"posted_at" => "invalid-datetime"}
      result = Normalize.transaction_attrs(attrs)
      # Should remain unchanged
      assert result["posted_at"] == "invalid-datetime"
    end
  end
end

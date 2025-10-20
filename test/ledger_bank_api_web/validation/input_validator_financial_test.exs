defmodule LedgerBankApiWeb.Validation.InputValidatorFinancialTest do
  use ExUnit.Case, async: true
  alias LedgerBankApiWeb.Validation.InputValidator

  describe "validate_payment_creation/1" do
    test "validates valid payment creation parameters" do
      params = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test payment",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:ok, validated_params} = InputValidator.validate_payment_creation(params)
      assert validated_params.amount == Decimal.new("100.50")
      assert validated_params.direction == "CREDIT"
      assert validated_params.payment_type == "TRANSFER"
      assert validated_params.description == "Test payment"
      assert validated_params.user_bank_account_id == "123e4567-e89b-12d3-a456-426614174000"
    end

    test "returns error for missing amount" do
      params = %{
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test payment",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end

    test "returns error for invalid amount format" do
      params = %{
        "amount" => "invalid",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test payment",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end

    test "returns error for negative amount" do
      params = %{
        "amount" => "-100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test payment",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end

    test "returns error for invalid direction" do
      params = %{
        "amount" => "100.50",
        "direction" => "invalid",
        "payment_type" => "transfer",
        "description" => "Test payment",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end

    test "returns error for invalid payment type" do
      params = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "invalid",
        "description" => "Test payment",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end

    test "returns error for missing description" do
      params = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end

    test "returns error for missing user_bank_account_id" do
      params = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test payment"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end

    test "returns error for invalid UUID format" do
      params = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test payment",
        "user_bank_account_id" => "invalid-uuid"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end
  end

  describe "validate_bank_account_creation/1" do
    test "validates valid bank account creation parameters" do
      params = %{
        "currency" => "usd",
        "account_type" => "checking",
        "account_name" => "My Checking Account",
        "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000",
        "last_four" => "1234",
        "external_account_id" => "ext_123"
      }

      assert {:ok, validated_params} = InputValidator.validate_bank_account_creation(params)
      assert validated_params.currency == "USD"
      assert validated_params.account_type == "CHECKING"
      assert validated_params.account_name == "My Checking Account"
      assert validated_params.user_bank_login_id == "123e4567-e89b-12d3-a456-426614174000"
      assert validated_params.last_four == "1234"
      assert validated_params.external_account_id == "ext_123"
    end

    test "returns error for missing currency" do
      params = %{
        "account_type" => "checking",
        "account_name" => "My Checking Account",
        "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_bank_account_creation(params)
    end

    test "returns error for invalid currency format" do
      params = %{
        "currency" => "invalid",
        "account_type" => "checking",
        "account_name" => "My Checking Account",
        "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_bank_account_creation(params)
    end

    test "returns error for invalid account type" do
      params = %{
        "currency" => "usd",
        "account_type" => "invalid",
        "account_name" => "My Checking Account",
        "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_bank_account_creation(params)
    end

    test "returns error for missing account name" do
      params = %{
        "currency" => "usd",
        "account_type" => "checking",
        "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_bank_account_creation(params)
    end

    test "returns error for missing user_bank_login_id" do
      params = %{
        "currency" => "usd",
        "account_type" => "checking",
        "account_name" => "My Checking Account"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_bank_account_creation(params)
    end
  end

  describe "validate_transaction_filters/1" do
    test "validates valid transaction filter parameters" do
      params = %{
        "direction" => "credit",
        "date_from" => "2023-01-01T00:00:00Z",
        "date_to" => "2023-12-31T23:59:59Z"
      }

      assert {:ok, filters} = InputValidator.validate_transaction_filters(params)
      assert filters.direction == "CREDIT"
      assert filters.date_from == "2023-01-01T00:00:00Z"
      assert filters.date_to == "2023-12-31T23:59:59Z"
    end

    test "handles nil filter values" do
      params = %{
        "direction" => nil,
        "date_from" => nil,
        "date_to" => nil
      }

      assert {:ok, filters} = InputValidator.validate_transaction_filters(params)
      assert filters == %{}
    end

    test "handles empty params" do
      params = %{}

      assert {:ok, filters} = InputValidator.validate_transaction_filters(params)
      assert filters == %{}
    end

    test "returns error for invalid direction" do
      params = %{
        "direction" => "invalid"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_transaction_filters(params)
    end

    test "returns error for invalid date format" do
      params = %{
        "date_from" => "invalid-date"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_transaction_filters(params)
    end
  end

  describe "amount validation" do
    test "accepts valid decimal amounts" do
      params = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:ok, validated_params} = InputValidator.validate_payment_creation(params)
      assert validated_params.amount == Decimal.new("100.50")
    end

    test "accepts integer amounts" do
      params = %{
        "amount" => "100",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:ok, validated_params} = InputValidator.validate_payment_creation(params)
      assert validated_params.amount == Decimal.new("100")
    end

    test "rejects zero amounts" do
      params = %{
        "amount" => "0",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:error, %LedgerBankApi.Core.Error{}} =
               InputValidator.validate_payment_creation(params)
    end
  end

  describe "direction validation" do
    test "accepts credit direction" do
      params = %{
        "amount" => "100.50",
        "direction" => "credit",
        "payment_type" => "transfer",
        "description" => "Test",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:ok, validated_params} = InputValidator.validate_payment_creation(params)
      assert validated_params.direction == "CREDIT"
    end

    test "accepts debit direction" do
      params = %{
        "amount" => "100.50",
        "direction" => "debit",
        "payment_type" => "transfer",
        "description" => "Test",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:ok, validated_params} = InputValidator.validate_payment_creation(params)
      assert validated_params.direction == "DEBIT"
    end

    test "accepts uppercase directions" do
      params = %{
        "amount" => "100.50",
        "direction" => "CREDIT",
        "payment_type" => "transfer",
        "description" => "Test",
        "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:ok, validated_params} = InputValidator.validate_payment_creation(params)
      assert validated_params.direction == "CREDIT"
    end
  end

  describe "payment type validation" do
    test "accepts valid payment types" do
      valid_types = ["transfer", "payment", "deposit", "withdrawal"]

      for payment_type <- valid_types do
        params = %{
          "amount" => "100.50",
          "direction" => "credit",
          "payment_type" => payment_type,
          "description" => "Test",
          "user_bank_account_id" => "123e4567-e89b-12d3-a456-426614174000"
        }

        assert {:ok, validated_params} = InputValidator.validate_payment_creation(params)
        assert validated_params.payment_type == String.upcase(payment_type)
      end
    end
  end

  describe "currency validation" do
    test "accepts valid 3-letter currency codes" do
      valid_currencies = ["USD", "EUR", "GBP", "JPY", "CAD"]

      for currency <- valid_currencies do
        params = %{
          "currency" => currency,
          "account_type" => "checking",
          "account_name" => "Test Account",
          "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000"
        }

        assert {:ok, validated_params} = InputValidator.validate_bank_account_creation(params)
        assert validated_params.currency == currency
      end
    end

    test "normalizes lowercase currency codes" do
      params = %{
        "currency" => "usd",
        "account_type" => "checking",
        "account_name" => "Test Account",
        "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000"
      }

      assert {:ok, validated_params} = InputValidator.validate_bank_account_creation(params)
      assert validated_params.currency == "USD"
    end
  end

  describe "account type validation" do
    test "accepts valid account types" do
      valid_types = ["checking", "savings", "credit", "investment"]

      for account_type <- valid_types do
        params = %{
          "currency" => "usd",
          "account_type" => account_type,
          "account_name" => "Test Account",
          "user_bank_login_id" => "123e4567-e89b-12d3-a456-426614174000"
        }

        assert {:ok, validated_params} = InputValidator.validate_bank_account_creation(params)
        assert validated_params.account_type == String.upcase(account_type)
      end
    end
  end
end

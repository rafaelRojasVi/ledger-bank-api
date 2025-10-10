defmodule LedgerBankApi.Core.ErrorCatalogFinancialTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Core.ErrorCatalog

  describe "financial error reasons" do
    test "includes all financial business rule errors" do
      financial_errors = [
        :insufficient_funds,
        :account_inactive,
        :daily_limit_exceeded,
        :amount_exceeds_limit,
        :negative_amount,
        :negative_balance,
        :currency_mismatch
      ]

      for error <- financial_errors do
        assert ErrorCatalog.valid_reason?(error)
        assert ErrorCatalog.category_for_reason(error) == :business_rule
      end
    end

    test "includes all financial conflict errors" do
      financial_errors = [
        :already_processed,
        :duplicate_transaction
      ]

      for error <- financial_errors do
        assert ErrorCatalog.valid_reason?(error)
        assert ErrorCatalog.category_for_reason(error) == :conflict
      end
    end

    test "includes all financial validation errors" do
      financial_errors = [
        :invalid_payment_type,
        :invalid_currency_format,
        :invalid_account_type,
        :invalid_description_format,
        :invalid_account_name_format
      ]

      for error <- financial_errors do
        assert ErrorCatalog.valid_reason?(error)
        assert ErrorCatalog.category_for_reason(error) == :validation
      end
    end
  end

  describe "financial error messages" do
    test "provides appropriate messages for financial business rule errors" do
      assert ErrorCatalog.default_message_for_reason(:insufficient_funds) == "Insufficient funds for this transaction"
      assert ErrorCatalog.default_message_for_reason(:account_inactive) == "Account is inactive"
      assert ErrorCatalog.default_message_for_reason(:daily_limit_exceeded) == "Daily payment limit exceeded"
      assert ErrorCatalog.default_message_for_reason(:amount_exceeds_limit) == "Payment amount exceeds single transaction limit"
      assert ErrorCatalog.default_message_for_reason(:negative_amount) == "Payment amount cannot be negative"
      assert ErrorCatalog.default_message_for_reason(:negative_balance) == "Account balance cannot be negative"
      assert ErrorCatalog.default_message_for_reason(:currency_mismatch) == "Payment currency does not match account currency"
    end

    test "provides appropriate messages for financial conflict errors" do
      assert ErrorCatalog.default_message_for_reason(:already_processed) == "Resource has already been processed"
      assert ErrorCatalog.default_message_for_reason(:duplicate_transaction) == "Duplicate transaction"
    end

    test "provides appropriate messages for financial validation errors" do
      assert ErrorCatalog.default_message_for_reason(:invalid_payment_type) == "Invalid payment type"
      assert ErrorCatalog.default_message_for_reason(:invalid_currency_format) == "Invalid currency format"
      assert ErrorCatalog.default_message_for_reason(:invalid_account_type) == "Invalid account type"
      assert ErrorCatalog.default_message_for_reason(:invalid_description_format) == "Invalid description format"
      assert ErrorCatalog.default_message_for_reason(:invalid_account_name_format) == "Invalid account name format"
    end
  end

  describe "financial error categories" do
    test "business rule errors are categorized correctly" do
      business_rule_errors = ErrorCatalog.reasons_for_category(:business_rule)

      financial_business_errors = [
        :insufficient_funds,
        :account_inactive,
        :daily_limit_exceeded,
        :amount_exceeds_limit,
        :negative_amount,
        :negative_balance,
        :currency_mismatch
      ]

      for error <- financial_business_errors do
        assert error in business_rule_errors
      end
    end

    test "conflict errors are categorized correctly" do
      conflict_errors = ErrorCatalog.reasons_for_category(:conflict)

      financial_conflict_errors = [
        :already_processed,
        :duplicate_transaction
      ]

      for error <- financial_conflict_errors do
        assert error in conflict_errors
      end
    end

    test "validation errors are categorized correctly" do
      validation_errors = ErrorCatalog.reasons_for_category(:validation)

      financial_validation_errors = [
        :invalid_payment_type,
        :invalid_currency_format,
        :invalid_account_type,
        :invalid_description_format,
        :invalid_account_name_format
      ]

      for error <- financial_validation_errors do
        assert error in validation_errors
      end
    end
  end

  describe "error reason validation" do
    test "validates financial error reasons exist" do
      financial_errors = [
        :insufficient_funds,
        :account_inactive,
        :daily_limit_exceeded,
        :amount_exceeds_limit,
        :negative_amount,
        :negative_balance,
        :currency_mismatch,
        :already_processed,
        :duplicate_transaction,
        :invalid_payment_type,
        :invalid_currency_format,
        :invalid_account_type,
        :invalid_description_format,
        :invalid_account_name_format
      ]

      for error <- financial_errors do
        assert ErrorCatalog.valid_reason?(error)
      end
    end

    test "rejects invalid error reasons" do
      invalid_errors = [
        :invalid_financial_error,
        :nonexistent_error,
        :fake_error
      ]

      for error <- invalid_errors do
        refute ErrorCatalog.valid_reason?(error)
      end
    end
  end

  describe "error HTTP status mapping" do
    test "maps financial error categories to correct HTTP status codes" do
      # Business rule errors should map to 422
      assert ErrorCatalog.http_status_for_category(:business_rule) == 422

      # Conflict errors should map to 409
      assert ErrorCatalog.http_status_for_category(:conflict) == 409

      # Validation errors should map to 400
      assert ErrorCatalog.http_status_for_category(:validation) == 400
    end

    test "maps financial error categories to correct error types" do
      # Business rule errors should map to unprocessable_entity
      assert ErrorCatalog.error_type_for_category(:business_rule) == :unprocessable_entity

      # Conflict errors should map to conflict
      assert ErrorCatalog.error_type_for_category(:conflict) == :conflict

      # Validation errors should map to validation_error
      assert ErrorCatalog.error_type_for_category(:validation) == :validation_error
    end
  end
end

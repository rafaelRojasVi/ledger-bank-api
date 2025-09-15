defmodule LedgerBankApi.Banking.Schemas.BankTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Schemas.Bank

  describe "changeset/2" do
    test "valid changeset" do
      attrs = %{
        name: "Test Bank",
        country: "US",
        code: "TEST_BANK",
        logo_url: "https://example.com/logo.png",
        api_endpoint: "https://api.testbank.com",
        integration_module: "LedgerBankApi.Banking.Integrations.TestBankClient"
      }

      changeset = Bank.changeset(%Bank{}, attrs)

      assert changeset.valid?
    end

    test "invalid changeset with invalid country code" do
      attrs = %{
        name: "Test Bank",
        country: "USA",  # Should be 2 letters
        code: "TEST_BANK"
      }

      changeset = Bank.changeset(%Bank{}, attrs)

      refute changeset.valid?
      assert "must be a valid 2-letter country code (e.g., US, UK)" in errors_on(changeset).country
    end

    test "invalid changeset with invalid bank code" do
      attrs = %{
        name: "Test Bank",
        country: "US",
        code: "test-bank"  # Should be uppercase with underscores
      }

      changeset = Bank.changeset(%Bank{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset).code
    end

    test "invalid changeset with invalid integration module" do
      attrs = %{
        name: "Test Bank",
        country: "US",
        code: "TEST_BANK",
        integration_module: "invalid-module-name"  # Should be valid Elixir module
      }

      changeset = Bank.changeset(%Bank{}, attrs)

      refute changeset.valid?
      assert "must be a valid Elixir module name (e.g., MyApp.Module)" in errors_on(changeset).integration_module
    end

    test "invalid changeset with invalid URL" do
      attrs = %{
        name: "Test Bank",
        country: "US",
        code: "TEST_BANK",
        logo_url: "not-a-url"
      }

      changeset = Bank.changeset(%Bank{}, attrs)

      refute changeset.valid?
      assert "must be a valid URL starting with http:// or https://" in errors_on(changeset).logo_url
    end
  end

  describe "is_active?/1" do
    test "returns true for active bank" do
      bank = %Bank{status: "ACTIVE"}
      assert Bank.is_active?(bank)
    end

    test "returns false for inactive bank" do
      bank = %Bank{status: "INACTIVE"}
      refute Bank.is_active?(bank)
    end
  end

  describe "has_integration?/1" do
    test "returns true when integration module is set" do
      bank = %Bank{integration_module: "LedgerBankApi.Banking.Integrations.TestBankClient"}
      assert Bank.has_integration?(bank)
    end

    test "returns false when integration module is nil" do
      bank = %Bank{integration_module: nil}
      refute Bank.has_integration?(bank)
    end

    test "returns false when integration module is empty string" do
      bank = %Bank{integration_module: ""}
      refute Bank.has_integration?(bank)
    end
  end
end

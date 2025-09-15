defmodule LedgerBankApi.Banking.Schemas.BankBranchTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Schemas.BankBranch

  describe "changeset/2" do
    test "valid changeset" do
      attrs = %{
        name: "Main Branch",
        country: "US",
        bank_id: Ecto.UUID.generate(),
        iban: "US64SVBK1234567890123456",
        swift_code: "SVBKUS6S",
        routing_number: "123456789"
      }

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      assert changeset.valid?
    end

    test "invalid changeset with invalid country code" do
      attrs = %{
        name: "Main Branch",
        country: "USA",  # Should be 2 letters
        bank_id: Ecto.UUID.generate()
      }

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      refute changeset.valid?
      assert "must be a valid 2-letter country code (e.g., US, UK)" in errors_on(changeset).country
    end

    test "invalid changeset with invalid IBAN format" do
      attrs = %{
        name: "Main Branch",
        country: "US",
        bank_id: Ecto.UUID.generate(),
        iban: "INVALID_IBAN"
      }

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      refute changeset.valid?
      assert "must be a valid IBAN format" in errors_on(changeset).iban
    end

    test "invalid changeset with invalid SWIFT code format" do
      attrs = %{
        name: "Main Branch",
        country: "US",
        bank_id: Ecto.UUID.generate(),
        swift_code: "INVALID"
      }

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      refute changeset.valid?
      assert "must be a valid SWIFT/BIC code format" in errors_on(changeset).swift_code
    end

    test "invalid changeset with invalid routing number format" do
      attrs = %{
        name: "Main Branch",
        country: "US",
        bank_id: Ecto.UUID.generate(),
        routing_number: "12345"  # Should be exactly 9 digits
      }

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      refute changeset.valid?
      assert "must be exactly 9 digits" in errors_on(changeset).routing_number
    end

    test "invalid changeset with name too short" do
      attrs = %{
        name: "A",  # Too short
        country: "US",
        bank_id: Ecto.UUID.generate()
      }

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      refute changeset.valid?
      assert "should be at least 2 character(s)" in errors_on(changeset).name
    end

    test "invalid changeset with name too long" do
      attrs = %{
        name: String.duplicate("A", 101),  # Too long
        country: "US",
        bank_id: Ecto.UUID.generate()
      }

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).name
    end

    test "invalid changeset with missing required fields" do
      attrs = %{}

      changeset = BankBranch.changeset(%BankBranch{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset).name
      assert errors_on(changeset).country
      assert errors_on(changeset).bank_id
    end
  end

  describe "base_changeset/2" do
    test "valid base changeset" do
      attrs = %{
        name: "Test Branch",
        country: "GB",
        bank_id: Ecto.UUID.generate()
      }

      changeset = BankBranch.base_changeset(%BankBranch{}, attrs)

      assert changeset.valid?
    end

    test "base changeset allows optional fields" do
      attrs = %{
        name: "Test Branch",
        country: "GB",
        bank_id: Ecto.UUID.generate(),
        iban: "GB29NWBK60161331926819",
        swift_code: "NWBKGB2L",
        routing_number: "123456789"
      }

      changeset = BankBranch.base_changeset(%BankBranch{}, attrs)

      assert changeset.valid?
    end
  end
end

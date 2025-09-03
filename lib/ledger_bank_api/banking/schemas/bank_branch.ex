defmodule LedgerBankApi.Banking.Schemas.BankBranch do
  @moduledoc """
  Ecto schema for bank branches. Represents a branch of a bank, including IBAN, SWIFT, and routing info.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.CrudHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bank_branches" do
    field :name, :string
    field :iban, :string
    field :country, :string
    field :routing_number, :string
    field :swift_code, :string

    belongs_to :bank, LedgerBankApi.Banking.Schemas.Bank
    has_many :user_bank_logins, LedgerBankApi.Banking.Schemas.UserBankLogin

    timestamps(type: :utc_datetime)
  end

  @fields [:name, :iban, :country, :routing_number, :swift_code, :bank_id]
  @required_fields [:name, :country, :bank_id]

  default_changeset(:base_changeset, @fields, @required_fields)

  def changeset(bank_branch, attrs) do
    bank_branch
    |> base_changeset(attrs)
    |> unique_constraint(:iban)
    |> foreign_key_constraint(:bank_id)
    |> validate_country_code()
    |> validate_name_length()
    |> validate_iban_format()
    |> validate_swift_format()
    |> validate_routing_number_format()
  end

  defp validate_country_code(changeset) do
    validate_format(changeset, :country, ~r/^[A-Z]{2}$/, message: "must be a valid 2-letter country code (e.g., US, UK)")
  end

  defp validate_name_length(changeset) do
    validate_length(changeset, :name, min: 2, max: 100)
  end

  defp validate_iban_format(changeset) do
    iban = get_change(changeset, :iban)
    if is_nil(iban) or iban == "" do
      changeset
    else
      validate_format(changeset, :iban, ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]?){0,16}$/,
        message: "must be a valid IBAN format")
    end
  end

  defp validate_swift_format(changeset) do
    swift_code = get_change(changeset, :swift_code)
    if is_nil(swift_code) or swift_code == "" do
      changeset
    else
      validate_format(changeset, :swift_code, ~r/^[A-Z]{6}[A-Z2-9][A-NP-Z0-9]([A-Z0-9]{3})?$/,
        message: "must be a valid SWIFT/BIC code format")
    end
  end

  defp validate_routing_number_format(changeset) do
    routing_number = get_change(changeset, :routing_number)
    if is_nil(routing_number) or routing_number == "" do
      changeset
    else
      validate_format(changeset, :routing_number, ~r/^\d{9}$/,
        message: "must be exactly 9 digits")
    end
  end
end

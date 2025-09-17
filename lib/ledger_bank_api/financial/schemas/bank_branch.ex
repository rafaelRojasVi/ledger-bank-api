defmodule LedgerBankApi.Financial.Schemas.BankBranch do
  @moduledoc """
  Ecto schema for bank branches. Represents a branch of a bank, including IBAN, SWIFT, and routing info.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :iban, :country, :routing_number, :swift_code, :bank_id, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bank_branches" do
    field :name, :string
    field :iban, :string
    field :country, :string
    field :routing_number, :string
    field :swift_code, :string

    belongs_to :bank, LedgerBankApi.Financial.Schemas.Bank
    has_many :user_bank_logins, LedgerBankApi.Financial.Schemas.UserBankLogin

    timestamps(type: :utc_datetime)
  end

  @fields [:name, :iban, :country, :routing_number, :swift_code, :bank_id]
  @required_fields [:name, :country, :bank_id]

  def base_changeset(bank_branch, attrs) do
    bank_branch
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def changeset(bank_branch, attrs) do
    bank_branch
    |> base_changeset(attrs)
    |> unique_constraint(:iban, name: :bank_branches_iban_index)
    |> unique_constraint(:swift_code, name: :bank_branches_swift_code_index)
    |> foreign_key_constraint(:bank_id)
    |> validate_country_code()
    |> validate_name_length()
    |> validate_iban_format()
    |> validate_swift_format()
    |> validate_routing_number_format()
  end

  defp validate_country_code(changeset) do
    country = get_change(changeset, :country)
    if is_nil(country) do
      changeset
    else
      # Basic country code validation (2-3 letter codes)
      if String.match?(country, ~r/^[A-Z]{2,3}$/) do
        changeset
      else
        add_error(changeset, :country, "must be a valid country code (2-3 uppercase letters)")
      end
    end
  end

  defp validate_name_length(changeset) do
    changeset
    |> validate_length(:name, min: 2, max: 100)
  end

  defp validate_iban_format(changeset) do
    iban = get_change(changeset, :iban)
    if is_nil(iban) or iban == "" do
      changeset
    else
      # Basic IBAN format validation (2 letters + 2 digits + up to 30 alphanumeric)
      if String.match?(iban, ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$/) do
        changeset
      else
        add_error(changeset, :iban, "must be a valid IBAN format")
      end
    end
  end

  defp validate_swift_format(changeset) do
    swift_code = get_change(changeset, :swift_code)
    if is_nil(swift_code) or swift_code == "" do
      changeset
    else
      # SWIFT code format: 4 letters + 2 letters + 2 alphanumeric + 3 alphanumeric
      if String.match?(swift_code, ~r/^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}[A-Z0-9]{3}$/) do
        changeset
      else
        add_error(changeset, :swift_code, "must be a valid SWIFT code format")
      end
    end
  end

  defp validate_routing_number_format(changeset) do
    routing_number = get_change(changeset, :routing_number)
    if is_nil(routing_number) or routing_number == "" do
      changeset
    else
      # Basic routing number validation (9 digits)
      if String.match?(routing_number, ~r/^[0-9]{9}$/) do
        changeset
      else
        add_error(changeset, :routing_number, "must be a valid routing number (9 digits)")
      end
    end
  end

end

defmodule LedgerBankApi.Financial.Schemas.BankBranch do
  @moduledoc """
  Ecto schema for bank branches. Represents a branch of a bank, including IBAN, SWIFT, and routing info.
  """
  use LedgerBankApi.Core.SchemaHelpers

  @derive {Jason.Encoder, only: [:id, :name, :iban, :country, :routing_number, :swift_code, :bank_id, :inserted_at, :updated_at]}

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
    |> validate_country_code(:country)
    |> validate_name_length(:name)
    |> validate_iban_format(:iban)
    |> validate_swift_format(:swift_code)
    |> validate_routing_number_format(:routing_number)
  end
end

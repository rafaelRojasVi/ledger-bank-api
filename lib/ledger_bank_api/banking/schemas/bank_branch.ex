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
  end
end

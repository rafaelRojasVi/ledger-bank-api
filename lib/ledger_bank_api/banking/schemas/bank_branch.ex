defmodule LedgerBankApi.Banking.BankBranch do
  @moduledoc """
  Ecto schema for bank branches. Represents a branch of a bank, including IBAN, SWIFT, and routing info.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bank_branches" do
    field :name, :string
    field :iban, :string
    field :country, :string
    field :routing_number, :string
    field :swift_code, :string

    belongs_to :bank, LedgerBankApi.Banking.Bank
    has_many :user_bank_logins, LedgerBankApi.Banking.UserBankLogin

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for bank branch creation and updates.
  """
  def changeset(bank_branch, attrs) do
    bank_branch
    |> cast(attrs, [:name, :iban, :country, :routing_number, :swift_code, :bank_id])
    |> validate_required([:name, :country, :bank_id])
    |> unique_constraint(:iban)
    |> foreign_key_constraint(:bank_id)
  end
end

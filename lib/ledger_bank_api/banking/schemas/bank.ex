defmodule LedgerBankApi.Banking.Schemas.Bank do
  @moduledoc """
  Ecto schema for banks. Represents a financial institution.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "banks" do
    field :name, :string
    field :country, :string
    field :logo_url, :string
    field :api_endpoint, :string
    field :status, :string, default: "ACTIVE"
    field :integration_module, :string

    has_many :bank_branches, LedgerBankApi.Banking.Schemas.BankBranch

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for bank creation and updates.
  """
  def changeset(bank, attrs) do
    bank
    |> cast(attrs, [:name, :country, :logo_url, :api_endpoint, :status, :integration_module])
    |> validate_required([:name, :country])
    |> unique_constraint(:name)
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE"])
  end
end

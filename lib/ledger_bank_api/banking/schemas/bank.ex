defmodule LedgerBankApi.Banking.Schemas.Bank do
  @moduledoc """
  Ecto schema for banks. Represents a financial institution.
  """
  use Ecto.Schema
  import LedgerBankApi.CrudHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "banks" do
    field :name, :string
    field :country, :string
    field :logo_url, :string
    field :api_endpoint, :string
    field :status, :string, default: "ACTIVE"
    field :integration_module, :string
    field :code, :string

    has_many :bank_branches, LedgerBankApi.Banking.Schemas.BankBranch

    timestamps(type: :utc_datetime)
  end

  @fields [:name, :country, :logo_url, :api_endpoint, :status, :integration_module, :code]
  @required_fields [:name, :country, :code]

  default_changeset(:base_changeset, @fields, @required_fields)

  def changeset(bank, attrs) do
    bank
    |> base_changeset(attrs)
    |> unique_constraints([:name, :code])
    |> validate_inclusions([status: ["ACTIVE", "INACTIVE"]])
    |> validate_formats([code: ~r/^[A-Z0-9_]+$/])
    |> validate_lengths([code: [min: 3, max: 32]])
  end
end

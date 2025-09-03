defmodule LedgerBankApi.Banking.Schemas.Bank do
  @moduledoc """
  Ecto schema for banks. Represents a financial institution.
  """
  use Ecto.Schema
  import Ecto.Changeset
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
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE"])
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/)
    |> validate_length(:code, min: 3, max: 32)
    |> validate_country_code()
    |> validate_name_length()
    |> validate_url_format()
  end

  defp validate_country_code(changeset) do
    validate_format(changeset, :country, ~r/^[A-Z]{2}$/, message: "must be a valid 2-letter country code (e.g., US, UK)")
  end

  defp validate_name_length(changeset) do
    validate_length(changeset, :name, min: 2, max: 100)
  end

  defp validate_url_format(changeset) do
    logo_url = get_change(changeset, :logo_url)
    api_endpoint = get_change(changeset, :api_endpoint)

    changeset
    |> validate_url_field(:logo_url, logo_url)
    |> validate_url_field(:api_endpoint, api_endpoint)
  end

  defp validate_url_field(changeset, field, value) do
    if is_nil(value) or value == "" do
      changeset
    else
      validate_format(changeset, field, ~r/^https?:\/\/.+/, message: "must be a valid URL starting with http:// or https://")
    end
  end
end

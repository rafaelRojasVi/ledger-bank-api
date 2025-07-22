defmodule LedgerBankApi.Banking.Schemas.Account do
  @moduledoc """
  Ecto schema for bank accounts. Represents a user's account at a financial institution.
  """
  use Ecto.Schema
  import LedgerBankApi.CrudHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounts" do
    field :type, :string
    field :balance, :decimal
    field :user_id, Ecto.UUID
    field :institution, :string
    field :last4, :string

    timestamps(type: :utc_datetime)
  end

  @fields [:user_id, :institution, :type, :last4, :balance]
  @required_fields [:user_id, :institution, :type, :last4, :balance]

  default_changeset(:base_changeset, @fields, @required_fields)

  def changeset(struct, attrs), do: base_changeset(struct, attrs)
end

defmodule LedgerBankApi.Banking.Schemas.Transaction do
  @moduledoc """
  Ecto schema for transactions. Represents a financial transaction on a user account.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.CrudHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :description, :string
    field :amount, :decimal
    field :direction, :string # "CREDIT" or "DEBIT"
    field :posted_at, :utc_datetime
    belongs_to :user_bank_account, LedgerBankApi.Banking.Schemas.UserBankAccount, foreign_key: :account_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @fields [:amount, :posted_at, :description, :account_id, :direction]
  @required_fields [:amount, :posted_at, :description, :account_id, :direction]

  default_changeset(:base_changeset, @fields, @required_fields)

  def changeset(struct, attrs) do
    struct
    |> base_changeset(attrs)
    |> validate_inclusion(:direction, ["CREDIT", "DEBIT"])
    |> validate_amount_positive()
  end

  defp validate_amount_positive(changeset) do
    case get_field(changeset, :amount) do
      nil -> changeset
      amount ->
        if Decimal.lt?(amount, Decimal.new(0)) do
          add_error(changeset, :amount, "must be positive")
        else
          changeset
        end
    end
  end
end

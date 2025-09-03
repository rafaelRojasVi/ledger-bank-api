defmodule LedgerBankApi.Banking.Schemas.Transaction do
  @moduledoc """
  Ecto schema for transactions. Represents a financial transaction on a user account.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.CrudHelpers
  import LedgerBankApi.Helpers.ValidationHelpers

  @derive Jason.Encoder

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
    |> validate_description_length()
    |> validate_posted_at_not_future()
    |> foreign_key_constraint(:account_id)
  end

  defp validate_description_length(changeset) do
    description = get_change(changeset, :description)
    if is_nil(description) or description == "" do
      changeset
    else
      validate_length(changeset, :description, max: 500)
    end
  end

  defp validate_posted_at_not_future(changeset) do
    posted_at = get_change(changeset, :posted_at)
    if is_nil(posted_at) do
      changeset
    else
      if DateTime.compare(posted_at, DateTime.utc_now()) == :gt do
        add_error(changeset, :posted_at, "cannot be in the future")
      else
        changeset
      end
    end
  end
end

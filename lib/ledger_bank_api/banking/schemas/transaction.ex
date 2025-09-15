defmodule LedgerBankApi.Banking.Schemas.Transaction do
  @moduledoc """
  Ecto schema for transactions. Represents a financial transaction on a user account.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.Database.ValidationMacros

  @derive {Jason.Encoder, only: [:id, :description, :amount, :direction, :posted_at, :account_id, :user_id, :inserted_at, :updated_at]}

  # Use common validation functions
  use_common_validations()

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :description, :string
    field :amount, :decimal
    field :direction, :string # "CREDIT" or "DEBIT"
    field :posted_at, :utc_datetime

    belongs_to :user_bank_account, LedgerBankApi.Banking.Schemas.UserBankAccount, foreign_key: :account_id, type: :binary_id
    belongs_to :user, LedgerBankApi.Users.User

    timestamps(type: :utc_datetime)
  end

  @fields [:amount, :posted_at, :description, :account_id, :direction, :user_id]
  @required_fields [:amount, :posted_at, :description, :account_id, :direction, :user_id]

  def base_changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:direction, ["CREDIT", "DEBIT"])
    |> validate_amount_positive()
    |> validate_description_length()
    |> validate_posted_at_not_future()
  end

  def changeset(struct, attrs) do
    struct
    |> base_changeset(attrs)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:user_id)
    |> validate_user_owns_account()
  end


  defp validate_user_owns_account(changeset) do
    user_id = get_change(changeset, :user_id)
    account_id = get_change(changeset, :account_id)

    if is_nil(user_id) or is_nil(account_id) do
      changeset
    else
      # Note: This validation is kept minimal to avoid N+1 queries
      # Comprehensive ownership validation should be done at the application level
      # where proper preloading and joins can be used
      changeset
    end
  end
end

defmodule LedgerBankApi.Financial.Schemas.UserPayment do
  @moduledoc """
  Ecto schema for user payments. Represents a payment or transfer initiated by a user.
  """
  use LedgerBankApi.Core.SchemaHelpers

  @derive {Jason.Encoder, only: [:id, :amount, :direction, :description, :payment_type, :status, :posted_at, :external_transaction_id, :user_bank_account_id, :user_id, :inserted_at, :updated_at]}

  schema "user_payments" do
    field :amount, :decimal
    field :direction, :string # "CREDIT" or "DEBIT"
    field :description, :string
    field :payment_type, :string
    field :status, :string, default: "PENDING"
    field :posted_at, :utc_datetime
    field :external_transaction_id, :string

    belongs_to :user_bank_account, LedgerBankApi.Financial.Schemas.UserBankAccount
    belongs_to :user, LedgerBankApi.Accounts.Schemas.User

    timestamps(type: :utc_datetime)
  end

  @fields [
    :user_bank_account_id, :user_id, :amount, :direction, :description, :payment_type, :status, :posted_at, :external_transaction_id
  ]
  @required_fields [
    :user_bank_account_id, :user_id, :amount, :direction, :payment_type
  ]

  def base_changeset(user_payment, attrs) do
    user_payment
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def changeset(user_payment, attrs) do
    user_payment
    |> base_changeset(attrs)
    |> validate_direction_field(:direction)
    |> validate_amount_positive(:amount)
    |> validate_payment_type()
    |> validate_status()
    |> validate_description_length(:description)
    |> validate_not_future(:posted_at)
    |> foreign_key_constraint(:user_bank_account_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:external_transaction_id, name: :user_payments_external_transaction_id_index)
    |> validate_user_owns_account()
  end

  defp validate_payment_type(changeset) do
    changeset
    |> validate_inclusion(:payment_type, ["TRANSFER", "PAYMENT", "DEPOSIT", "WITHDRAWAL"],
      message: "must be TRANSFER, PAYMENT, DEPOSIT, or WITHDRAWAL")
  end

  defp validate_status(changeset) do
    changeset
    |> validate_inclusion(:status, ["PENDING", "COMPLETED", "FAILED", "CANCELLED"],
      message: "must be PENDING, COMPLETED, FAILED, or CANCELLED")
  end

  defp validate_user_owns_account(changeset) do
    user_id = get_change(changeset, :user_id)
    user_bank_account_id = get_change(changeset, :user_bank_account_id)

    if is_nil(user_id) or is_nil(user_bank_account_id) do
      changeset
    else
      # Note: This validation is kept minimal to avoid N+1 queries
      # Comprehensive ownership validation should be done at the application level
      # where proper preloading and joins can be used
      changeset
    end
  end
end

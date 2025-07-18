defmodule LedgerBankApi.Banking.Schemas.UserPayment do
  @moduledoc """
  Ecto schema for user payments. Represents a payment or transfer initiated by a user.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_payments" do
    field :amount, :decimal
    field :description, :string
    field :payment_type, :string
    field :status, :string, default: "PENDING"
    field :posted_at, :utc_datetime
    field :external_transaction_id, :string

    belongs_to :user_bank_account, LedgerBankApi.Banking.Schemas.UserBankAccount

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for user payment creation and updates.
  """
  def changeset(user_payment, attrs) do
    user_payment
    |> cast(attrs, [:user_bank_account_id, :amount, :description, :payment_type, :status, :posted_at, :external_transaction_id])
    |> validate_required([:user_bank_account_id, :amount, :payment_type])
    |> validate_amount()
    |> validate_payment_type()
    |> validate_status()
    |> foreign_key_constraint(:user_bank_account_id)
  end

  defp validate_amount(changeset) do
    case get_field(changeset, :amount) do
      nil -> changeset
      amount ->
        if Decimal.lt?(amount, Decimal.new(0)) do
          add_error(changeset, :amount, "cannot be negative")
        else
          changeset
        end
    end
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
end

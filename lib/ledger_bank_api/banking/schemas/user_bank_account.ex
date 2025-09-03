defmodule LedgerBankApi.Banking.Schemas.UserBankAccount do
  @moduledoc """
  Ecto schema for user bank accounts. Represents a user's linked account at a bank branch, including balance and status.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.CrudHelpers

  @derive {Jason.Encoder, only: [:id, :currency, :account_type, :balance, :last_four, :account_name, :status, :last_sync_at, :external_account_id, :user_bank_login_id, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_bank_accounts" do
    field :currency, :string
    field :account_type, :string
    field :balance, :decimal, default: 0.0
    field :last_four, :string
    field :account_name, :string
    field :status, :string, default: "ACTIVE"
    field :last_sync_at, :utc_datetime
    field :external_account_id, :string

    belongs_to :user_bank_login, LedgerBankApi.Banking.Schemas.UserBankLogin
    has_many :user_payments, LedgerBankApi.Banking.Schemas.UserPayment
    has_many :transactions, LedgerBankApi.Banking.Schemas.Transaction, foreign_key: :account_id

    timestamps(type: :utc_datetime)
  end

  @fields [
    :user_bank_login_id, :currency, :account_type, :balance, :last_four, :account_name, :status, :last_sync_at, :external_account_id
  ]
  @required_fields [
    :user_bank_login_id, :currency, :account_type
  ]

  default_changeset(:base_changeset, @fields, @required_fields)

  def changeset(user_bank_account, attrs) do
    user_bank_account
    |> base_changeset(attrs)
    |> validate_inclusion(:account_type, ["CHECKING", "SAVINGS", "CREDIT", "INVESTMENT"])
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE", "CLOSED"])
    |> validate_currency_format()
    |> validate_balance_format()
    |> validate_last_four_format()
    |> validate_account_name_length()
    |> foreign_key_constraint(:user_bank_login_id)
  end

  defp validate_currency_format(changeset) do
    validate_format(changeset, :currency, ~r/^[A-Z]{3}$/, message: "must be a valid 3-letter currency code (e.g., USD, EUR)")
  end

  defp validate_balance_format(changeset) do
    balance = get_change(changeset, :balance)
    if is_nil(balance) do
      changeset
    else
      if Decimal.lt?(balance, Decimal.new(0)) do
        add_error(changeset, :balance, "cannot be negative")
      else
        changeset
      end
    end
  end

  defp validate_last_four_format(changeset) do
    last_four = get_change(changeset, :last_four)
    if is_nil(last_four) or last_four == "" do
      changeset
    else
      validate_format(changeset, :last_four, ~r/^\d{4}$/, message: "must be exactly 4 digits")
    end
  end

  defp validate_account_name_length(changeset) do
    validate_length(changeset, :account_name, min: 1, max: 100)
  end
end

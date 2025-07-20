defmodule LedgerBankApi.Banking.Schemas.UserBankAccount do
  @moduledoc """
  Ecto schema for user bank accounts. Represents a user's linked account at a bank branch, including balance and status.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.CrudHelpers

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
    |> foreign_key_constraint(:user_bank_login_id)
  end
end

defmodule LedgerBankApi.Banking.UserBankAccount do
  @moduledoc """
  Ecto schema for user bank accounts. Represents a user's linked account at a bank branch, including balance and status.
  """
  use Ecto.Schema
  import Ecto.Changeset

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

    belongs_to :user_bank_login, LedgerBankApi.Banking.UserBankLogin
    has_many :user_payments, LedgerBankApi.Banking.UserPayment
    has_many :transactions, LedgerBankApi.Banking.Transaction, foreign_key: :account_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for user bank account creation and updates.
  """
  def changeset(user_bank_account, attrs) do
    user_bank_account
    |> cast(attrs, [:user_bank_login_id, :currency, :account_type, :balance, :last_four, :account_name, :status, :last_sync_at, :external_account_id])
    |> validate_required([:user_bank_login_id, :currency, :account_type])
    |> validate_inclusion(:account_type, ["CHECKING", "SAVINGS", "CREDIT", "INVESTMENT"])
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE", "CLOSED"])
    |> foreign_key_constraint(:user_bank_login_id)
  end
end

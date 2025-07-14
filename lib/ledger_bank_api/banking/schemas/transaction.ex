defmodule LedgerBankApi.Banking.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :description, :string
    field :amount, :decimal
    field :posted_at, :utc_datetime
    belongs_to :user_bank_account, LedgerBankApi.Banking.UserBankAccount, foreign_key: :account_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :posted_at, :description, :account_id])
    |> validate_required([:amount, :posted_at, :description, :account_id])
  end
end

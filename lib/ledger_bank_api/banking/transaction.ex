defmodule LedgerBankApi.Banking.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :description, :string
    field :amount, :decimal
    field :posted_at, :utc_datetime
    field :account_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :posted_at, :description])
    |> validate_required([:amount, :posted_at, :description])
  end
end

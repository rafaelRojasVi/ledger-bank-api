defmodule LedgerBankApi.Banking.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounts" do
    field :type, :string
    field :balance, :decimal
    field :user_id, Ecto.UUID
    field :institution, :string
    field :last4, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:user_id, :institution, :type, :last4, :balance])
    |> validate_required([:user_id, :institution, :type, :last4, :balance])
  end
end

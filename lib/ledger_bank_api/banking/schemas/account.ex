defmodule LedgerBankApi.Banking.Account do
  @moduledoc """
  Ecto schema for bank accounts. Represents a user's account at a financial institution.
  """
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

  @doc """
  Builds a changeset for account creation and updates.
  """
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:user_id, :institution, :type, :last4, :balance])
    |> validate_required([:user_id, :institution, :type, :last4, :balance])
  end
end

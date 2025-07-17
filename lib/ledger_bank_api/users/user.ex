defmodule LedgerBankApi.Users.User do
  @moduledoc """
  Ecto schema for application users. Represents a registered user with email, name, and status.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :full_name, :string
    field :status, :string, default: "ACTIVE"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for user creation and updates.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :full_name, :status])
    |> validate_required([:email, :full_name])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_inclusion(:status, ["ACTIVE", "SUSPENDED"])
  end
end

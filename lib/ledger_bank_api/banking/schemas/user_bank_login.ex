defmodule LedgerBankApi.Banking.UserBankLogin do
  @moduledoc """
  Ecto schema for user bank logins. Represents a user's login credentials for a specific bank branch.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_bank_logins" do
    field :username, :string
    field :encrypted_password, :string
    field :status, :string, default: "ACTIVE"
    field :last_sync_at, :utc_datetime
    field :sync_frequency, :integer, default: 3600 # seconds

    belongs_to :user, LedgerBankApi.Users.User
    belongs_to :bank_branch, LedgerBankApi.Banking.BankBranch
    has_many :user_bank_accounts, LedgerBankApi.Banking.UserBankAccount

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for user bank login creation and updates.
  """
  def changeset(user_bank_login, attrs) do
    user_bank_login
    |> cast(attrs, [:user_id, :bank_branch_id, :username, :encrypted_password, :status, :last_sync_at, :sync_frequency])
    |> validate_required([:user_id, :bank_branch_id, :username, :encrypted_password])
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE", "ERROR"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:bank_branch_id)
  end
end

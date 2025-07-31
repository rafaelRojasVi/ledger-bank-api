defmodule LedgerBankApi.Banking.Schemas.UserBankLogin do
  @moduledoc """
  Ecto schema for user bank logins. Represents a user's login credentials for a specific bank branch.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.CrudHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_bank_logins" do
    field :username, :string
    field :encrypted_password, :string
    field :status, :string, default: "ACTIVE"
    field :last_sync_at, :utc_datetime
    field :sync_frequency, :integer, default: 3600 # seconds

    belongs_to :user, LedgerBankApi.Users.User
    belongs_to :bank_branch, LedgerBankApi.Banking.Schemas.BankBranch
    has_many :user_bank_accounts, LedgerBankApi.Banking.Schemas.UserBankAccount

    timestamps(type: :utc_datetime)
  end

  @fields [
    :user_id, :bank_branch_id, :username, :encrypted_password, :status, :last_sync_at, :sync_frequency
  ]
  @required_fields [
    :user_id, :bank_branch_id, :username, :encrypted_password
  ]

  @doc """
  Builds a changeset for user bank login creation and updates.
  """
  def changeset(user_bank_login, attrs) do
    user_bank_login
    |> base_changeset(attrs)
    |> validate_inclusions([status: ["ACTIVE", "INACTIVE", "ERROR"]])
    |> foreign_key_constraints([:user_id, :bank_branch_id])
    |> unique_constraints([:user_id, :bank_branch_id, :username])
    |> unique_constraint(:user_id, name: "user_bank_logins_user_id_bank_branch_id_index")
  end

  default_changeset(:base_changeset, @fields, @required_fields)
end

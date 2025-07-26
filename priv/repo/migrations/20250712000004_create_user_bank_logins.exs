defmodule LedgerBankApi.Repo.Migrations.CreateUserBankLogins do
  use Ecto.Migration

  def change do
    create table(:user_bank_logins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :encrypted_password, :string, null: false
      add :status, :string, null: false, default: "ACTIVE"
      add :last_sync_at, :utc_datetime
      add :sync_frequency, :integer, default: 3600
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :bank_branch_id, references(:bank_branches, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_bank_logins, [:user_id])
    create index(:user_bank_logins, [:bank_branch_id])
    create index(:user_bank_logins, [:status])
    create unique_index(:user_bank_logins, [:user_id, :bank_branch_id])
  end
end

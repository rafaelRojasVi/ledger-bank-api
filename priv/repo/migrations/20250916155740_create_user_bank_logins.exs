defmodule LedgerBankApi.Repo.Migrations.CreateUserBankLogins do
  use Ecto.Migration

  def change do
    create table(:user_bank_logins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :status, :string, default: "ACTIVE", null: false
      add :last_sync_at, :utc_datetime
      add :sync_frequency, :integer, default: 3600, null: false

      # OAuth2 fields
      add :access_token, :text
      add :refresh_token, :text
      add :token_expires_at, :utc_datetime
      add :scope, :string
      add :provider_user_id, :string

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :bank_branch_id, references(:bank_branches, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_bank_logins, [:user_id], name: :user_bank_logins_user_id_index)
    create index(:user_bank_logins, [:bank_branch_id], name: :user_bank_logins_bank_branch_id_index)
    create index(:user_bank_logins, [:status], name: :user_bank_logins_status_index)
    create unique_index(:user_bank_logins, [:user_id, :bank_branch_id, :username], name: :user_bank_logins_user_id_bank_branch_id_username_index)
  end
end

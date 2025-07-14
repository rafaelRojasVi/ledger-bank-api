defmodule LedgerBankApi.Repo.Migrations.CreateUserBankAccounts do
  use Ecto.Migration

  def change do
    create table(:user_bank_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :currency, :string, null: false
      add :account_type, :string, null: false
      add :balance, :decimal, precision: 20, scale: 2, default: 0.0
      add :last_four, :string
      add :account_name, :string
      add :status, :string, null: false, default: "ACTIVE"
      add :last_sync_at, :utc_datetime
      add :external_account_id, :string
      add :user_bank_login_id, references(:user_bank_logins, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_bank_accounts, [:user_bank_login_id])
    create index(:user_bank_accounts, [:external_account_id])
    create index(:user_bank_accounts, [:account_type])
    create index(:user_bank_accounts, [:status])
  end
end

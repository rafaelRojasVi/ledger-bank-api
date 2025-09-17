defmodule LedgerBankApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :full_name, :string, null: false
      add :status, :string, default: "ACTIVE", null: false
      add :role, :string, default: "user", null: false
      add :password_hash, :string, null: false
      add :active, :boolean, default: true, null: false
      add :verified, :boolean, default: false, null: false
      add :suspended, :boolean, default: false, null: false
      add :deleted, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email], name: :users_email_index)
    create index(:users, [:status], name: :users_status_index)
    create index(:users, [:role], name: :users_role_index)
    create index(:users, [:active], name: :users_active_index)
    create index(:users, [:verified], name: :users_verified_index)
    create index(:users, [:suspended], name: :users_suspended_index)
    create index(:users, [:deleted], name: :users_deleted_index)
    create index(:users, [:inserted_at], name: :users_inserted_at_index)
    create index(:users, [:updated_at], name: :users_updated_at_index)
  end
end

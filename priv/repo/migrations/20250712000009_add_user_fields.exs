defmodule LedgerBankApi.Repo.Migrations.AddUserFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :active, :boolean, default: true, null: false
      add :verified, :boolean, default: false, null: false
      add :suspended, :boolean, default: false, null: false
      add :deleted, :boolean, default: false, null: false
    end

    # Add indexes for better query performance
    create index(:users, [:active])
    create index(:users, [:verified])
    create index(:users, [:suspended])
    create index(:users, [:deleted])
  end
end

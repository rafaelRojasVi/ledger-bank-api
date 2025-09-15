defmodule LedgerBankApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :full_name, :string, null: false
      add :status, :string, null: false, default: "ACTIVE"
      add :role, :string, null: false, default: "user"
      add :password_hash, :string, null: false

      timestamps(type: :utc_datetime)
    end

    # Add indexes for better query performance
    create unique_index(:users, [:email])
    create index(:users, [:status])
    create index(:users, [:role])
    create index(:users, [:inserted_at])
    create index(:users, [:updated_at])
  end
end

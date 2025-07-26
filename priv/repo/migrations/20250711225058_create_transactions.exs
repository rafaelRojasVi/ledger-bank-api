defmodule LedgerBankApi.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :restrict)
      add :description, :string
      add :amount, :decimal
      add :posted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Add indexes for better query performance
    create index(:transactions, [:account_id])
    create index(:transactions, [:posted_at])
    create index(:transactions, [:amount])
    create index(:transactions, [:account_id, :posted_at])
    create index(:transactions, [:inserted_at])
    create index(:transactions, [:updated_at])
  end
end

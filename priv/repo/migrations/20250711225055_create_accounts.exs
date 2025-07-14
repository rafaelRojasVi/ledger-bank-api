defmodule LedgerBankApi.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :uuid
      add :institution, :string
      add :type, :string
      add :last4, :string
      add :balance, :decimal

      timestamps(type: :utc_datetime)
    end

    # Add indexes for better query performance
    create index(:accounts, [:user_id])
    create index(:accounts, [:institution])
    create index(:accounts, [:type])
    create index(:accounts, [:user_id, :institution])
    create index(:accounts, [:inserted_at])
    create index(:accounts, [:updated_at])
  end
end

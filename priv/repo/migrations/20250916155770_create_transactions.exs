defmodule LedgerBankApi.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :description, :string, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :direction, :string, null: false
      add :posted_at, :utc_datetime, null: false

      add :account_id, references(:user_bank_accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:account_id], name: :transactions_account_id_index)
    create index(:transactions, [:posted_at], name: :transactions_posted_at_index)
    create index(:transactions, [:amount], name: :transactions_amount_index)
    create index(:transactions, [:direction], name: :transactions_direction_index)
    create index(:transactions, [:account_id, :posted_at], name: :transactions_account_id_posted_at_index)
  end
end

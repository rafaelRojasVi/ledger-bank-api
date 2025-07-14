defmodule LedgerBankApi.Repo.Migrations.CreateUserPayments do
  use Ecto.Migration

  def change do
    create table(:user_payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_bank_account_id, references(:user_bank_accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :decimal, precision: 20, scale: 2, null: false
      add :description, :string
      add :payment_type, :string, null: false
      add :status, :string, null: false, default: "PENDING"
      add :posted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Add indexes for better query performance
    create index(:user_payments, [:user_bank_account_id])
    create index(:user_payments, [:amount])
    create index(:user_payments, [:payment_type])
    create index(:user_payments, [:status])
    create index(:user_payments, [:posted_at])
    create index(:user_payments, [:inserted_at])
    create index(:user_payments, [:updated_at])
  end
end

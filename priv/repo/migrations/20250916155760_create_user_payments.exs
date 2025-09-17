defmodule LedgerBankApi.Repo.Migrations.CreateUserPayments do
  use Ecto.Migration

  def change do
    create table(:user_payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :direction, :string, null: false
      add :description, :string
      add :payment_type, :string, null: false
      add :status, :string, default: "PENDING", null: false
      add :posted_at, :utc_datetime
      add :external_transaction_id, :string

      add :user_bank_account_id, references(:user_bank_accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_payments, [:user_bank_account_id], name: :user_payments_user_bank_account_id_index)
    create index(:user_payments, [:amount], name: :user_payments_amount_index)
    create index(:user_payments, [:payment_type], name: :user_payments_payment_type_index)
    create index(:user_payments, [:status], name: :user_payments_status_index)
    create index(:user_payments, [:direction], name: :user_payments_direction_index)
    create index(:user_payments, [:posted_at], name: :user_payments_posted_at_index)
    create index(:user_payments, [:external_transaction_id], name: :user_payments_external_transaction_id_index)
  end
end

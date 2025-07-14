defmodule LedgerBankApi.Repo.Migrations.UpdateUserPaymentsNewStructure do
  use Ecto.Migration

  def change do
    # Remove old user_id column and add new foreign key
    alter table(:user_payments) do
      remove :user_id
      add :user_bank_account_id, references(:user_bank_accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :external_transaction_id, :string
    end

    create index(:user_payments, [:user_bank_account_id])
    create index(:user_payments, [:external_transaction_id])
  end
end

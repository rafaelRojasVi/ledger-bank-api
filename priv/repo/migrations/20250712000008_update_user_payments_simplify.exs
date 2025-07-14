defmodule LedgerBankApi.Repo.Migrations.UpdateUserPaymentsSimplify do
  use Ecto.Migration

  def change do
    # Remove the foreign key constraint and column
    alter table(:user_payments) do
      remove :user_bank_account_id
      add :user_id, :uuid
    end

    # Add index for user_id
    create index(:user_payments, [:user_id])
  end
end

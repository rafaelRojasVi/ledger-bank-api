defmodule LedgerBankApi.Repo.Migrations.UpdateTransactionsAccountIdFk do
  use Ecto.Migration

  def change do
    # Drop the existing foreign key constraint
    alter table(:transactions) do
      remove :account_id
    end

    alter table(:transactions) do
      add :account_id, references(:user_bank_accounts, type: :binary_id, on_delete: :delete_all)
    end

    create index(:transactions, [:account_id])
  end
end

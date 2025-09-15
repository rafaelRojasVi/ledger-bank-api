defmodule LedgerBankApi.Repo.Migrations.AddDirectionToTransactions do
  use Ecto.Migration

  def up do
    alter table(:transactions) do
      add :direction, :string, default: "DEBIT"
    end

    # Ensure all existing rows have a value (the default will be used for new and existing rows)
    execute("UPDATE transactions SET direction = 'DEBIT' WHERE direction IS NULL")

    alter table(:transactions) do
      modify :direction, :string, null: false
    end
  end

  def down do
    alter table(:transactions) do
      remove :direction
    end
  end
end

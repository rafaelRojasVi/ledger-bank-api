defmodule LedgerBankApi.Repo.Migrations.AddDirectionToUserPayments do
  use Ecto.Migration

  def up do
    alter table(:user_payments) do
      add :direction, :string, default: "DEBIT"
    end

    execute("UPDATE user_payments SET direction = 'DEBIT' WHERE direction IS NULL")

    alter table(:user_payments) do
      modify :direction, :string, null: false
    end
  end

  def down do
    alter table(:user_payments) do
      remove :direction
    end
  end
end

defmodule LedgerBankApi.Repo.Migrations.AddUniqueIndexToUserBankLogins do
  use Ecto.Migration

  def up do
    create unique_index(:user_bank_logins, [:user_id, :bank_branch_id, :username])
  end

  def down do
    drop index(:user_bank_logins, [:user_id, :bank_branch_id, :username])
  end
end

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
  end
end

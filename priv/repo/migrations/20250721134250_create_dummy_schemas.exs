defmodule LedgerBankApi.Repo.Migrations.CreateDummySchemas do
  use Ecto.Migration

  def change do
    create table(:dummy_schemas, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string
      add :role, :string
    end
  end
end

defmodule LedgerBankApi.Repo.Migrations.CreateBankBranches do
  use Ecto.Migration

  def change do
    create table(:bank_branches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :iban, :string
      add :country, :string, null: false
      add :routing_number, :string
      add :swift_code, :string
      add :bank_id, references(:banks, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bank_branches, [:iban])
    create index(:bank_branches, [:bank_id])
    create index(:bank_branches, [:country])
  end
end

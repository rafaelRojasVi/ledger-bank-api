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

    create unique_index(:bank_branches, [:iban], name: :bank_branches_iban_index)
    create unique_index(:bank_branches, [:swift_code], name: :bank_branches_swift_code_index)
    create index(:bank_branches, [:bank_id], name: :bank_branches_bank_id_index)
    create index(:bank_branches, [:country], name: :bank_branches_country_index)
  end
end

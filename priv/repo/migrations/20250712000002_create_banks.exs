defmodule LedgerBankApi.Repo.Migrations.CreateBanks do
  use Ecto.Migration

  def change do
    create table(:banks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :country, :string, null: false
      add :logo_url, :string
      add :api_endpoint, :string
      add :status, :string, null: false, default: "ACTIVE"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:banks, [:name])
    create index(:banks, [:country])
    create index(:banks, [:status])
  end
end

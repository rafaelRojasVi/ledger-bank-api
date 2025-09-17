defmodule LedgerBankApi.Repo.Migrations.CreateBanks do
  use Ecto.Migration

  def change do
    create table(:banks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :country, :string, null: false
      add :code, :string, null: false
      add :logo_url, :string
      add :api_endpoint, :string
      add :status, :string, default: "ACTIVE", null: false
      add :integration_module, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:banks, [:name], name: :banks_name_index)
    create unique_index(:banks, [:code], name: :banks_code_index)
    create index(:banks, [:country], name: :banks_country_index)
    create index(:banks, [:status], name: :banks_status_index)
  end
end

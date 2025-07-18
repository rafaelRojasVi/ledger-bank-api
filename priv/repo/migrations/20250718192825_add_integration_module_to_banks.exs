defmodule LedgerBankApi.Repo.Migrations.AddIntegrationModuleToBanks do
  use Ecto.Migration

  def change do
    alter table(:banks) do
      add :integration_module, :string
    end
  end
end

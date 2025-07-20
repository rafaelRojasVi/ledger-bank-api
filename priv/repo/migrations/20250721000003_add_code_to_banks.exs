defmodule LedgerBankApi.Repo.Migrations.AddCodeToBanks do
  use Ecto.Migration

  def up do
    alter table(:banks) do
      add :code, :string
    end
    execute("UPDATE banks SET code = lower(replace(name, ' ', '_')) || '_' || lower(country) WHERE code IS NULL")
    alter table(:banks) do
      modify :code, :string, null: false
    end
    create unique_index(:banks, [:code])
  end

  def down do
    alter table(:banks) do
      remove :code
    end
  end
end

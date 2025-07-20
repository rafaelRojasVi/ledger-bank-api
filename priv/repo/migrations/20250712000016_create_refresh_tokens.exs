defmodule LedgerBankApi.Repo.Migrations.CreateRefreshTokens do
  use Ecto.Migration

  def change do
    create table(:refresh_tokens) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :jti, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime

      timestamps()
    end

    create unique_index(:refresh_tokens, [:jti])
    create index(:refresh_tokens, [:user_id])
  end
end

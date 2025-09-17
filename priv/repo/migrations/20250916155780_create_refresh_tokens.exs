defmodule LedgerBankApi.Repo.Migrations.CreateRefreshTokens do
  use Ecto.Migration

  def change do
    create table(:refresh_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :jti, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:refresh_tokens, [:jti], name: :refresh_tokens_jti_index)
    create index(:refresh_tokens, [:user_id], name: :refresh_tokens_user_id_index)
    create index(:refresh_tokens, [:expires_at], name: :refresh_tokens_expires_at_index)
    create index(:refresh_tokens, [:revoked_at], name: :refresh_tokens_revoked_at_index)
  end
end

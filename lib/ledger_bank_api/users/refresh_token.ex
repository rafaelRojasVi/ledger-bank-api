
defmodule LedgerBankApi.Users.RefreshToken do
  @moduledoc """
  Ecto schema for refresh tokens. Used for secure session management and revocation.
  Fields:
    - user_id: references the user
    - jti: unique token identifier (from JWT)
    - expires_at: when the token expires
    - revoked_at: when the token was revoked (if any)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :jti, :expires_at, :revoked_at, :user_id, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "refresh_tokens" do
    field :jti, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    belongs_to :user, LedgerBankApi.Users.User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a refresh token.
  """
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:user_id, :jti, :expires_at, :revoked_at])
    |> validate_required([:user_id, :jti, :expires_at])
    |> unique_constraint(:jti, name: :refresh_tokens_jti_index)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Returns true if the token is revoked.
  """
  def revoked?(%__MODULE__{revoked_at: nil}), do: false
  def revoked?(%__MODULE__{revoked_at: _}), do: true

  @doc """
  Returns true if the token is expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end
end

defmodule LedgerBankApi.Accounts.Schemas.RefreshToken do
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

  @derive {Jason.Encoder,
           only: [:id, :jti, :expires_at, :revoked_at, :user_id, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "refresh_tokens" do
    field(:jti, :string)
    field(:expires_at, :utc_datetime)
    field(:revoked_at, :utc_datetime)
    belongs_to(:user, LedgerBankApi.Accounts.Schemas.User, type: :binary_id)

    timestamps(type: :utc_datetime)
  end

  @fields [:user_id, :jti, :expires_at, :revoked_at]
  @required_fields [:user_id, :jti, :expires_at]

  @doc """
  Base changeset for refresh token operations.
  """
  def base_changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Changeset for creating a refresh token.
  """
  def changeset(struct, attrs) do
    struct
    |> base_changeset(attrs)
    |> validate_future_expiration()
    |> unique_constraint(:jti, name: :refresh_tokens_jti_index)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_future_expiration(changeset) do
    expires_at = get_change(changeset, :expires_at)

    if expires_at && DateTime.compare(DateTime.utc_now(), expires_at) != :lt do
      add_error(changeset, :expires_at, "must be in the future")
    else
      changeset
    end
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

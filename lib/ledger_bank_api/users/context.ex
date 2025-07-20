defmodule LedgerBankApi.Users.Context do
  @moduledoc """
  The Users context for LedgerBankApi.
  Provides functions for managing application users, including creation, updates, status changes, roles, authentication, and refresh token management.
  Valid roles: "user", "admin", "support".
  Passwords are securely hashed using Argon2 and never stored in plaintext.
  Refresh tokens are stored in the database for revocation and session management.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Users.RefreshToken
  alias LedgerBankApi.Auth.JWT

  use LedgerBankApi.CrudHelpers, schema: User

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Returns list of active users.
  """
  def list_active_users do
    User
    |> where(status: "ACTIVE")
    |> Repo.all()
  end

  @doc """
  Returns list of suspended users.
  """
  def list_suspended_users do
    User
    |> where(status: "SUSPENDED")
    |> Repo.all()
  end

  @doc """
  Returns list of users by role.
  """
  def list_users_by_role(role) do
    User
    |> where([u], u.role == ^role)
    |> Repo.all()
  end

  @doc """
  Suspends a user.
  """
  def suspend_user(%User{} = user) do
    __MODULE__.update(user, %{status: "SUSPENDED"})
  end

  @doc """
  Activates a user.
  """
  def activate_user(%User{} = user) do
    __MODULE__.update(user, %{status: "ACTIVE"})
  end

  @doc """
  Creates a user, allowing role to be set (defaults to "user" if not provided).
  """
  def create_user(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :role, "user")
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Authenticates a user by email and password.
  On success, returns {:ok, user, access_token, refresh_token}.
  On failure, returns {:error, :invalid_credentials}.
  Passwords are verified using Argon2.
  Stores the refresh token in the database.
  """
  def login_user(email, password) do
    case get_user_by_email(email) do
      %User{status: "ACTIVE"} = user ->
        if verify_password(password, user) do
          {:ok, access_token} = JWT.generate_access_token(user)
          {:ok, refresh_token} = JWT.generate_refresh_token(user)
          {:ok, _db_token} = store_refresh_token(user, refresh_token)
          {:ok, user, access_token, refresh_token}
        else
          {:error, :invalid_credentials}
        end
      _ ->
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Refreshes tokens using a valid refresh token.
  Checks the database for token validity and revocation.
  Returns {:ok, user, new_access_token, new_refresh_token} or {:error, reason}.
  Rotates the refresh token (revokes the old one, issues a new one).
  """
  def refresh_tokens(refresh_token) do
    with {:ok, claims} <- JWT.verify_token(refresh_token),
         true <- claims["type"] == "refresh",
         user_id when is_binary(user_id) <- claims["sub"],
         jti when is_binary(jti) <- claims["jti"],
         %User{} = user <- Repo.get(User, user_id),
         true <- user.status == "ACTIVE",
         %RefreshToken{} = db_token <- get_refresh_token_by_jti(jti),
         false <- RefreshToken.revoked?(db_token),
         false <- RefreshToken.expired?(db_token),
         {:ok, new_access_token, new_refresh_token} <- JWT.refresh_access_token(refresh_token),
         {:ok, _} <- revoke_refresh_token(db_token),
         {:ok, _} <- store_refresh_token(user, new_refresh_token) do
      {:ok, user, new_access_token, new_refresh_token}
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  @doc """
  Stores a refresh token in the database.
  Extracts jti and expiry from the JWT claims.
  """
  def store_refresh_token(%User{id: user_id}, token) do
    with {:ok, claims} <- JWT.verify_token(token),
         jti when is_binary(jti) <- claims["jti"],
         exp when is_integer(exp) <- claims["exp"],
         expires_at <- DateTime.from_unix!(exp) do
      %RefreshToken{}
      |> RefreshToken.changeset(%{
        user_id: user_id,
        jti: jti,
        expires_at: expires_at
      })
      |> Repo.insert()
    end
  end

  @doc """
  Gets a refresh token by jti.
  """
  def get_refresh_token_by_jti(jti) do
    Repo.get_by(RefreshToken, jti: jti)
  end

  @doc """
  Revokes a refresh token (sets revoked_at).
  """
  def revoke_refresh_token(%RefreshToken{} = token) do
    token
    |> RefreshToken.changeset(%{revoked_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Revokes all refresh tokens for a user (e.g., on logout or password change).
  """
  def revoke_all_refresh_tokens_for_user(user_id) do
    from(t in RefreshToken, where: t.user_id == ^user_id and is_nil(t.revoked_at))
    |> Repo.update_all(set: [revoked_at: DateTime.utc_now()])
  end

  # Secure password verification using Argon2
  defp verify_password(password, %User{password_hash: hash}) when is_binary(hash) and byte_size(hash) > 0 do
    Argon2.verify_pass(password, hash)
  end
  defp verify_password(_, _), do: false
end

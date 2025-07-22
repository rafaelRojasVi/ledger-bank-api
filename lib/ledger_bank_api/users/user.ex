defmodule LedgerBankApi.Users.User do
  @moduledoc """
  Ecto schema for application users. Represents a registered user with email, name, status, and role.
  Valid roles: "user", "admin", "support".
  Passwords are securely hashed using Argon2 and never stored in plaintext.
  Password requirements: minimum 8 characters, at least one letter and one number.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import LedgerBankApi.CrudHelpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :full_name, :string
    field :status, :string, default: "ACTIVE"
    field :role, :string, default: "user"
    field :password_hash, :string
    # Virtual field for password (not stored in DB)
    field :password, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for user creation and updates.
  Hashes the password if present.
  Validates password length and complexity if present.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :full_name, :status, :role, :password])
    |> require_fields([:email, :full_name, :role])
    |> validate_formats([email: ~r/@/])
    |> unique_constraints([:email])
    |> validate_inclusions([status: ["ACTIVE", "SUSPENDED"], role: ["user", "admin", "support"]])
    |> validate_lengths([password: [min: 8]])
    |> validate_password()
    |> maybe_hash_password()
  end

  defp validate_password(changeset) do
    password = get_change(changeset, :password)
    if is_nil(password) do
      changeset
    else
      changeset
      |> validate_length(:password, min: 8)
      |> validate_format(:password, ~r/[a-zA-Z]/, message: "must contain at least one letter")
      |> validate_format(:password, ~r/\d/, message: "must contain at least one number")
    end
  end

  defp maybe_hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password ->
        put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
    end
  end

  @doc """
  Returns true if the user is an admin.
  """
  def is_admin?(%__MODULE__{role: "admin"}), do: true
  def is_admin?(_), do: false

  @doc """
  Returns true if the user has the given role.
  """
  def has_role?(%__MODULE__{role: "admin"}, _), do: true
  def has_role?(%__MODULE__{role: role}, role), do: true
  def has_role?(_, _), do: false
end

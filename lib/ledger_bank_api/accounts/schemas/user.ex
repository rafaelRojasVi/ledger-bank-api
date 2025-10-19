defmodule LedgerBankApi.Accounts.Schemas.User do
  @moduledoc """
  Ecto schema for application users.

  ## Architecture Role

  This module provides **data layer validation** for user records. It focuses on:
  - **Data integrity**: Field formats, constraints, and database-level validation
  - **Password hashing**: Secure password storage using PBKDF2
  - **Basic validation**: Email format, role inclusion, status validation

  ## Responsibilities

  - **Data Format Validation**: Email format, role inclusion, status validation
  - **Password Security**: Hashing and basic length validation (8+ characters)
  - **Database Constraints**: Unique constraints, foreign keys, required fields
  - **No Business Logic**: Does not handle permissions, role-based validation, or complex business rules

  ## Layer Separation

  - **Schema Validation** (this module): Data integrity and format validation
  - **Service Layer**: Business logic validation (permissions, role-based rules)
  - **InputValidator**: Web layer validation with proper error formatting
  - **Core Validator**: Reusable data format validation

  ## Valid Values

  - **Roles**: "user", "admin", "support"
  - **Status**: "ACTIVE", "SUSPENDED", "DELETED"
  - **Password**: Minimum 8 characters (role-based requirements handled at service layer)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :email, :full_name, :status, :role, :active, :verified, :suspended, :deleted, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :full_name, :string
    field :status, :string, default: "ACTIVE"
    field :role, :string, default: "user"
    field :password_hash, :string
    field :active, :boolean, default: true
    field :verified, :boolean, default: false
    field :suspended, :boolean, default: false
    field :deleted, :boolean, default: false
    # Virtual field for password (not stored in DB)
    field :password, :string, virtual: true
    # Virtual field for password confirmation
    field :password_confirmation, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @fields [:email, :full_name, :status, :role, :password, :password_confirmation, :active, :verified, :suspended, :deleted]
  @required_fields [:email, :full_name, :role]

  @doc """
  Base changeset for user operations.
  """
  def base_changeset(user, attrs) do
    user
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Builds a changeset for user creation and updates.
  Hashes the password if present.
  Validates password length and complexity if present.
  """
  def changeset(user, attrs) do
    user
    |> base_changeset(attrs)
    |> validate_email()
    |> validate_status()
    |> validate_role()
    |> validate_password()
    |> validate_password_confirmation()
    |> maybe_hash_password()
  end

  @doc """
  Builds a changeset for user updates (without password).
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :full_name, :status, :role, :active, :verified, :suspended, :deleted])
    |> validate_required(@required_fields)
    |> validate_email()
    |> validate_status()
    |> validate_role()
  end

  @doc """
  Builds a changeset for password changes only.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_password()
    |> validate_password_confirmation()
    |> maybe_hash_password()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "must be a valid email address")
    |> validate_length(:email, max: 255)
    |> unique_constraint(:email, name: :users_email_index)
  end

  defp validate_status(changeset) do
    validate_inclusion(changeset, :status, ["ACTIVE", "SUSPENDED", "DELETED"])
  end

  defp validate_password(changeset) do
    password = get_change(changeset, :password)
    if is_nil(password) do
      changeset
    else
      # Simple password validation - minimum 8 characters for all users
      # Role-based validation will be handled at the service layer
      changeset
      |> validate_length(:password, min: 8, max: 255,
          message: "must be at least 8 characters long")
    end
  end

  defp validate_password_confirmation(changeset) do
    password = get_change(changeset, :password)
    password_confirmation = get_change(changeset, :password_confirmation)

    if is_nil(password) or is_nil(password_confirmation) do
      changeset
    else
      if password == password_confirmation do
        changeset
      else
        add_error(changeset, :password_confirmation, "does not match password")
      end
    end
  end

  defp validate_role(changeset) do
    validate_inclusion(changeset, :role, ["user", "admin", "support"])
  end

  defp maybe_hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password ->
        hash_function = if Mix.env() == :test do
          &LedgerBankApi.PasswordHelper.hash_pwd_salt/1
        else
          &Pbkdf2.hash_pwd_salt/1
        end

        put_change(changeset, :password_hash, hash_function.(password))
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

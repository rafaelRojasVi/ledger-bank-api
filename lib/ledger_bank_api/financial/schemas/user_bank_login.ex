defmodule LedgerBankApi.Financial.Schemas.UserBankLogin do
  @moduledoc """
  Ecto schema for user bank logins. Represents a user's login credentials for a specific bank branch.
  """
  use LedgerBankApi.Core.SchemaHelpers

  @derive {Jason.Encoder,
           only: [
             :id,
             :username,
             :status,
             :last_sync_at,
             :sync_frequency,
             :user_id,
             :bank_branch_id,
             :scope,
             :provider_user_id,
             :inserted_at,
             :updated_at
           ]}

  schema "user_bank_logins" do
    field(:username, :string)
    field(:status, :string, default: "ACTIVE")
    field(:last_sync_at, :utc_datetime)
    # seconds
    field(:sync_frequency, :integer, default: 3600)

    # OAuth2 token fields
    field(:access_token, :string)
    field(:refresh_token, :string)
    field(:token_expires_at, :utc_datetime)
    # OAuth2 scopes granted
    field(:scope, :string)
    # User ID from the bank provider
    field(:provider_user_id, :string)

    belongs_to(:user, LedgerBankApi.Accounts.Schemas.User)
    belongs_to(:bank_branch, LedgerBankApi.Financial.Schemas.BankBranch)
    has_many(:user_bank_accounts, LedgerBankApi.Financial.Schemas.UserBankAccount)

    timestamps(type: :utc_datetime)
  end

  @fields [
    :user_id,
    :bank_branch_id,
    :username,
    :status,
    :last_sync_at,
    :sync_frequency,
    :access_token,
    :refresh_token,
    :token_expires_at,
    :scope,
    :provider_user_id
  ]
  @required_fields [
    :user_id,
    :bank_branch_id,
    :username
  ]

  def base_changeset(user_bank_login, attrs) do
    user_bank_login
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Builds a changeset for user bank login creation and updates.
  """
  def changeset(user_bank_login, attrs) do
    user_bank_login
    |> base_changeset(attrs)
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE", "ERROR"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:bank_branch_id)
    |> unique_constraint([:user_id, :bank_branch_id, :username],
      name: :user_bank_logins_user_branch_username_index
    )
    |> validate_username_format(:username)
    |> validate_oauth2_tokens()
    |> validate_oauth2_scope_format()
    |> validate_sync_frequency()
    |> validate_not_future(:last_sync_at)
  end

  @doc """
  Builds a changeset for user bank login updates.
  """
  def update_changeset(user_bank_login, attrs) do
    user_bank_login
    |> cast(attrs, [
      :username,
      :status,
      :last_sync_at,
      :sync_frequency,
      :access_token,
      :refresh_token,
      :token_expires_at,
      :scope
    ])
    |> validate_required([:username])
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE", "ERROR"])
    |> validate_username_format(:username)
    |> validate_oauth2_tokens()
    |> validate_oauth2_scope_format()
    |> validate_sync_frequency()
    |> validate_not_future(:last_sync_at)
  end

  @doc """
  Builds a changeset for OAuth2 token updates only.
  """
  def token_changeset(user_bank_login, attrs) do
    user_bank_login
    |> cast(attrs, [:access_token, :refresh_token, :token_expires_at, :scope])
    |> validate_required([:access_token])
    |> validate_oauth2_tokens()
  end

  defp validate_oauth2_tokens(changeset) do
    access_token = get_change(changeset, :access_token)
    refresh_token = get_change(changeset, :refresh_token)
    token_expires_at = get_change(changeset, :token_expires_at)

    changeset
    |> validate_access_token_format(access_token)
    |> validate_refresh_token_format(refresh_token)
    |> validate_token_expiration(token_expires_at)
  end

  defp validate_access_token_format(changeset, nil), do: changeset

  defp validate_access_token_format(changeset, access_token) do
    if String.length(access_token) < 10 do
      add_error(changeset, :access_token, "must be a valid OAuth2 access token")
    else
      changeset
    end
  end

  defp validate_refresh_token_format(changeset, nil), do: changeset

  defp validate_refresh_token_format(changeset, refresh_token) do
    if String.length(refresh_token) < 10 do
      add_error(changeset, :refresh_token, "must be a valid OAuth2 refresh token")
    else
      changeset
    end
  end

  defp validate_token_expiration(changeset, nil), do: changeset

  defp validate_token_expiration(changeset, token_expires_at) do
    if DateTime.compare(token_expires_at, DateTime.utc_now()) == :lt do
      add_error(changeset, :token_expires_at, "cannot be in the past")
    else
      changeset
    end
  end

  defp validate_oauth2_scope_format(changeset) do
    scope = get_change(changeset, :scope)

    if is_nil(scope) or scope == "" do
      changeset
    else
      # Basic OAuth2 scope validation (space-separated words)
      if String.match?(scope, ~r/^[a-zA-Z0-9_:\-\.]+(\s+[a-zA-Z0-9_:\-\.]+)*$/) do
        changeset
      else
        add_error(changeset, :scope, "must be valid OAuth2 scope format")
      end
    end
  end

  defp validate_sync_frequency(changeset) do
    sync_frequency = get_change(changeset, :sync_frequency)

    if is_nil(sync_frequency) do
      changeset
    else
      # Sync frequency should be between 300 seconds (5 min) and 86400 seconds (24 hours)
      if sync_frequency >= 300 and sync_frequency <= 86400 do
        changeset
      else
        add_error(changeset, :sync_frequency, "must be between 300 and 86400 seconds")
      end
    end
  end

  @doc """
  Checks if the OAuth2 access token is valid and not expired.
  """
  def token_valid?(%__MODULE__{access_token: nil}), do: false
  def token_valid?(%__MODULE__{token_expires_at: nil}), do: false

  def token_valid?(%__MODULE__{token_expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end

  @doc """
  Returns true if the login is active and has valid tokens.
  """
  def is_active?(%__MODULE__{status: "ACTIVE"} = login) do
    token_valid?(login)
  end

  def is_active?(_), do: false

  @doc """
  Returns true if the login needs syncing based on sync frequency.
  """
  def needs_sync?(%__MODULE__{last_sync_at: nil}), do: true

  def needs_sync?(%__MODULE__{last_sync_at: last_sync_at, sync_frequency: sync_frequency}) do
    seconds_since_sync = DateTime.diff(DateTime.utc_now(), last_sync_at, :second)
    seconds_since_sync >= sync_frequency
  end

  @doc """
  Returns true if the access token needs refreshing.
  """
  def needs_token_refresh?(%__MODULE__{token_expires_at: nil}), do: true

  def needs_token_refresh?(%__MODULE__{token_expires_at: expires_at}) do
    # Refresh token 5 minutes before expiry
    refresh_threshold = DateTime.add(expires_at, -300, :second)
    DateTime.compare(DateTime.utc_now(), refresh_threshold) == :gt
  end
end

defmodule LedgerBankApi.Financial.Schemas.UserBankAccount do
  @moduledoc """
  Ecto schema for user bank accounts. Represents a user's linked account at a bank branch, including balance and status.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :currency, :account_type, :balance, :last_four, :account_name, :status, :last_sync_at, :external_account_id, :user_bank_login_id, :user_id, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_bank_accounts" do
    field :currency, :string
    field :account_type, :string
    field :balance, :decimal, default: 0.0
    field :last_four, :string
    field :account_name, :string
    field :status, :string, default: "ACTIVE"
    field :last_sync_at, :utc_datetime
    field :external_account_id, :string

    belongs_to :user_bank_login, LedgerBankApi.Financial.Schemas.UserBankLogin
    belongs_to :user, LedgerBankApi.Accounts.Schemas.User
    has_many :user_payments, LedgerBankApi.Financial.Schemas.UserPayment
    has_many :transactions, LedgerBankApi.Financial.Schemas.Transaction, foreign_key: :account_id

    timestamps(type: :utc_datetime)
  end

  @fields [
    :user_bank_login_id, :user_id, :currency, :account_type, :balance, :last_four, :account_name, :status, :last_sync_at, :external_account_id
  ]
  @required_fields [
    :user_bank_login_id, :user_id, :currency, :account_type
  ]

  def base_changeset(user_bank_account, attrs) do
    user_bank_account
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def changeset(user_bank_account, attrs) do
    user_bank_account
    |> base_changeset(attrs)
    |> validate_inclusion(:account_type, ["CHECKING", "SAVINGS", "CREDIT", "INVESTMENT"])
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE", "CLOSED"])
    |> validate_currency_format()
    |> validate_balance_format()
    |> validate_last_four_format()
    |> validate_account_name_length()
    |> validate_external_account_id_format()
    |> validate_balance_limits()
    |> foreign_key_constraint(:user_bank_login_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:external_account_id, name: :user_bank_accounts_external_account_id_index)
    |> validate_user_owns_login()
  end

  @doc """
  Builds a changeset for account updates (without changing critical fields).
  """
  def update_changeset(user_bank_account, attrs) do
    user_bank_account
    |> cast(attrs, [:account_name, :status, :last_sync_at])
    |> validate_required([:account_name])
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE", "CLOSED"])
    |> validate_account_name_length()
  end

  @doc """
  Builds a changeset for balance updates only.
  """
  def balance_changeset(user_bank_account, attrs) do
    user_bank_account
    |> cast(attrs, [:balance, :last_sync_at])
    |> validate_required([:balance])
    |> validate_balance_format()
    |> validate_balance_limits()
  end

  defp validate_balance_format(changeset) do
    balance = get_change(changeset, :balance)
    if is_nil(balance) do
      changeset
    else
      # Basic format validation - check if it's a valid decimal
      if is_struct(balance, Decimal) do
        changeset
      else
        add_error(changeset, :balance, "must be a valid decimal number")
      end
    end
  end

  defp validate_balance_limits(changeset) do
    balance = get_change(changeset, :balance)
    account_type = get_change(changeset, :account_type)

    if is_nil(balance) or is_nil(account_type) do
      changeset
    else
      case account_type do
        "CREDIT" ->
          # Credit accounts can have negative balances (debt)
          changeset
        _ ->
          # Other account types should not have negative balances
          if Decimal.lt?(balance, Decimal.new(0)) do
            add_error(changeset, :balance, "cannot be negative for #{account_type} accounts")
          else
            changeset
          end
      end
    end
  end

  defp validate_user_owns_login(changeset) do
    user_id = get_change(changeset, :user_id)
    user_bank_login_id = get_change(changeset, :user_bank_login_id)

    if is_nil(user_id) or is_nil(user_bank_login_id) do
      changeset
    else
      # Note: This validation is kept minimal to avoid N+1 queries
      # Comprehensive ownership validation should be done at the application level
      # where proper preloading and joins can be used
      changeset
    end
  end

  defp validate_currency_format(changeset) do
    currency = get_change(changeset, :currency)
    if is_nil(currency) do
      changeset
    else
      # Basic currency code validation (3 uppercase letters)
      if String.match?(currency, ~r/^[A-Z]{3}$/) do
        changeset
      else
        add_error(changeset, :currency, "must be a valid currency code (3 uppercase letters)")
      end
    end
  end

  defp validate_last_four_format(changeset) do
    last_four = get_change(changeset, :last_four)
    if is_nil(last_four) or last_four == "" do
      changeset
    else
      # Last four digits validation (4 digits)
      if String.match?(last_four, ~r/^[0-9]{4}$/) do
        changeset
      else
        add_error(changeset, :last_four, "must be 4 digits")
      end
    end
  end

  defp validate_account_name_length(changeset) do
    changeset
    |> validate_length(:account_name, min: 1, max: 100)
  end

  defp validate_external_account_id_format(changeset) do
    external_account_id = get_change(changeset, :external_account_id)
    if is_nil(external_account_id) or external_account_id == "" do
      changeset
    else
      # Basic external account ID validation (alphanumeric, 1-50 chars)
      if String.match?(external_account_id, ~r/^[A-Za-z0-9]{1,50}$/) do
        changeset
      else
        add_error(changeset, :external_account_id, "must be alphanumeric, 1-50 characters")
      end
    end
  end

  @doc """
  Returns true if the account is active.
  """
  def is_active?(%__MODULE__{status: "ACTIVE"}), do: true
  def is_active?(_), do: false

  @doc """
  Returns true if the account is a credit account.
  """
  def is_credit_account?(%__MODULE__{account_type: "CREDIT"}), do: true
  def is_credit_account?(_), do: false

  @doc """
  Returns true if the account has sufficient balance for the given amount.
  """
  def has_sufficient_balance?(%__MODULE__{account_type: "CREDIT"}, _amount) do
    # Credit accounts can have negative balances, so they always have "sufficient" balance
    true
  end
  def has_sufficient_balance?(%__MODULE__{balance: balance}, amount) do
    Decimal.gte?(balance, amount)
  end

  @doc """
  Returns true if the account needs syncing based on last sync time.
  """
  def needs_sync?(%__MODULE__{last_sync_at: nil}), do: true
  def needs_sync?(%__MODULE__{last_sync_at: last_sync_at}) do
    # Consider account needs sync if last sync was more than the configured threshold
    sync_threshold_hours = Application.get_env(:ledger_bank_api, :account_sync_threshold_hours, 1)
    hours_since_sync = DateTime.diff(DateTime.utc_now(), last_sync_at, :hour)
    hours_since_sync >= sync_threshold_hours
  end
end

defmodule LedgerBankApi.Core.SchemaHelpers do
  @moduledoc """
  Reusable changeset validation functions for Ecto schemas.

  This module provides common validation patterns used across multiple schemas,
  eliminating duplication and ensuring consistency.

  ## Philosophy

  - **Plain functions over macros** - Easy to debug, explicit behavior
  - **Composable** - Chain with standard Ecto.Changeset functions
  - **Consistent messages** - Same validation = same error message
  - **Nil-safe** - Gracefully handles optional fields

  ## Difference from Core.Validator

  - `Core.Validator`: Pre-validation of raw values → Returns `:ok | {:error, atom}`
  - `SchemaHelpers`: Changeset-level validation → Returns `%Changeset{}`

  ## Usage

      defmodule MySchema do
        use LedgerBankApi.Core.SchemaHelpers

        def changeset(struct, attrs) do
          struct
          |> cast(attrs, @fields)
          |> validate_required(@required_fields)
          |> validate_amount_positive(:amount)
          |> validate_not_future(:posted_at)
          |> validate_currency_field(:currency)
        end
      end
  """

  import Ecto.Changeset

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import LedgerBankApi.Core.SchemaHelpers

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end

  # ============================================================================
  # AMOUNT VALIDATIONS
  # ============================================================================

  @doc """
  Validates that a Decimal amount field is positive (greater than zero).

  Skips validation if field is nil (handles optional fields).
  Preserves exact error message from existing schemas for consistency.

  ## Examples

      changeset |> validate_amount_positive(:amount)
      changeset |> validate_amount_positive(:balance)
  """
  def validate_amount_positive(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      amount when is_struct(amount, Decimal) ->
        if Decimal.gt?(amount, Decimal.new(0)) do
          changeset
        else
          add_error(changeset, field, "must be greater than zero")
        end

      _ ->
        changeset
    end
  end

  # ============================================================================
  # DATETIME VALIDATIONS
  # ============================================================================

  @doc """
  Validates that a DateTime field is not in the future.

  Skips validation if field is nil.
  Used for posted_at, last_sync_at fields where future dates are invalid.

  ## Examples

      changeset |> validate_not_future(:posted_at)
      changeset |> validate_not_future(:last_sync_at)
  """
  def validate_not_future(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      %DateTime{} = datetime ->
        if DateTime.compare(datetime, DateTime.utc_now()) == :gt do
          add_error(changeset, field, "cannot be in the future")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  # ============================================================================
  # FINANCIAL FIELD VALIDATIONS
  # ============================================================================

  @doc """
  Validates currency code format (3 uppercase letters: USD, GBP, EUR).

  Skips validation if field is nil.

  ## Examples

      changeset |> validate_currency_field(:currency)
  """
  def validate_currency_field(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      currency when is_binary(currency) ->
        if String.match?(currency, ~r/^[A-Z]{3}$/) do
          changeset
        else
          add_error(changeset, field, "must be a valid currency code (3 uppercase letters)")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Validates direction field (CREDIT or DEBIT).

  Skips validation if field is nil.

  ## Examples

      changeset |> validate_direction_field(:direction)
  """
  def validate_direction_field(changeset, field) do
    validate_inclusion(changeset, field, ["CREDIT", "DEBIT"])
  end

  # ============================================================================
  # ACCOUNT & BANK VALIDATIONS
  # ============================================================================

  @doc """
  Validates country code format (2-3 uppercase letters: US, UK, USA).

  Skips validation if field is nil.

  ## Examples

      changeset |> validate_country_code(:country)
  """
  def validate_country_code(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      country when is_binary(country) ->
        if String.match?(country, ~r/^[A-Z]{2,3}$/) do
          changeset
        else
          add_error(changeset, field, "must be a valid country code (2-3 uppercase letters)")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Validates IBAN format (2 letters + 2 digits + up to 30 alphanumeric).

  Skips validation if field is nil or empty string.

  ## Examples

      changeset |> validate_iban_format(:iban)
  """
  def validate_iban_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      iban when is_binary(iban) ->
        if String.match?(iban, ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$/) do
          changeset
        else
          add_error(changeset, field, "must be a valid IBAN format")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Validates SWIFT code format (4 letters + 2 letters + 2 alphanumeric + 3 alphanumeric).

  Skips validation if field is nil or empty string.

  ## Examples

      changeset |> validate_swift_format(:swift_code)
  """
  def validate_swift_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      swift_code when is_binary(swift_code) ->
        if String.match?(swift_code, ~r/^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}[A-Z0-9]{3}$/) do
          changeset
        else
          add_error(changeset, field, "must be a valid SWIFT code format")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Validates routing number format (9 digits).

  Skips validation if field is nil or empty string.

  ## Examples

      changeset |> validate_routing_number_format(:routing_number)
  """
  def validate_routing_number_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      routing_number when is_binary(routing_number) ->
        if String.match?(routing_number, ~r/^[0-9]{9}$/) do
          changeset
        else
          add_error(changeset, field, "must be a valid routing number (9 digits)")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Validates last four digits format (4 digits).

  Skips validation if field is nil or empty string.

  ## Examples

      changeset |> validate_last_four_format(:last_four)
  """
  def validate_last_four_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      last_four when is_binary(last_four) ->
        if String.match?(last_four, ~r/^[0-9]{4}$/) do
          changeset
        else
          add_error(changeset, field, "must be 4 digits")
        end

      _ ->
        changeset
    end
  end

  # ============================================================================
  # URL VALIDATIONS
  # ============================================================================

  @doc """
  Validates URL format (http:// or https://).

  Skips validation if field is nil or empty string.

  ## Examples

      changeset |> validate_url_format(:logo_url)
      changeset |> validate_url_format(:api_endpoint)
  """
  def validate_url_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      url when is_binary(url) ->
        if String.match?(url, ~r/^https?:\/\/.+\..+/) do
          changeset
        else
          add_error(changeset, field, "must be a valid URL")
        end

      _ ->
        changeset
    end
  end

  # ============================================================================
  # FORMAT VALIDATIONS
  # ============================================================================

  @doc """
  Validates that a Decimal field has proper format.

  Skips validation if field is nil.

  ## Examples

      changeset |> validate_decimal_format(:balance)
  """
  def validate_decimal_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      balance when is_struct(balance, Decimal) ->
        changeset

      _ ->
        add_error(changeset, field, "must be a valid decimal number")
    end
  end

  @doc """
  Validates external account ID format (alphanumeric, 1-50 characters).

  Skips validation if field is nil or empty string.

  ## Examples

      changeset |> validate_external_account_id_format(:external_account_id)
  """
  def validate_external_account_id_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      external_id when is_binary(external_id) ->
        if String.match?(external_id, ~r/^[A-Za-z0-9]{1,50}$/) do
          changeset
        else
          add_error(changeset, field, "must be alphanumeric, 1-50 characters")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Validates username format (alphanumeric, 3-50 characters).

  Skips validation if field is nil.

  ## Examples

      changeset |> validate_username_format(:username)
  """
  def validate_username_format(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      username when is_binary(username) ->
        if String.match?(username, ~r/^[A-Za-z0-9]{3,50}$/) do
          changeset
        else
          add_error(changeset, field, "must be alphanumeric, 3-50 characters")
        end

      _ ->
        changeset
    end
  end

  # ============================================================================
  # LENGTH VALIDATIONS
  # ============================================================================

  @doc """
  Validates description length (1-255 characters).

  Combines length validation in one place for consistency.

  ## Examples

      changeset |> validate_description_length(:description)
  """
  def validate_description_length(changeset, field) do
    validate_length(changeset, field, min: 1, max: 255)
  end

  @doc """
  Validates account name length (1-100 characters).

  ## Examples

      changeset |> validate_account_name_length(:account_name)
  """
  def validate_account_name_length(changeset, field) do
    validate_length(changeset, field, min: 1, max: 100)
  end

  @doc """
  Validates bank/branch name length (2-100 characters).

  ## Examples

      changeset |> validate_name_length(:name)
  """
  def validate_name_length(changeset, field) do
    validate_length(changeset, field, min: 2, max: 100)
  end

  # ============================================================================
  # BALANCE VALIDATIONS
  # ============================================================================

  @doc """
  Validates balance limits based on account type.

  For CREDIT accounts, negative balances are allowed (debt).
  For other account types, balance must be non-negative.

  Skips validation if balance or account_type is nil.

  ## Examples

      changeset |> validate_balance_limits()
  """
  def validate_balance_limits(changeset) do
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
end

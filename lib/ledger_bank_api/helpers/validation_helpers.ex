defmodule LedgerBankApi.Helpers.ValidationHelpers do
  @moduledoc """
  Shared validation helpers for common validation patterns across schemas.
  """

  import Ecto.Changeset

  @doc """
  Validates that an amount field is positive.
  """
  def validate_amount_positive(changeset, field \\ :amount) do
    case get_field(changeset, field) do
      nil -> changeset
      amount ->
        if Decimal.lt?(amount, Decimal.new(0)) do
          add_error(changeset, field, "must be positive")
        else
          changeset
        end
    end
  end

  @doc """
  Validates that a field is a valid email format.
  """
  def validate_email(changeset, field) do
    validate_format(changeset, field, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "must be a valid email address")
  end

  @doc """
  Validates that a field is a valid phone number format.
  """
  def validate_phone(changeset, field) do
    validate_format(changeset, field, ~r/^\+?[1-9]\d{1,14}$/, message: "must be a valid phone number")
  end

  @doc """
  Validates that a field is a valid URL format.
  """
  def validate_url(changeset, field) do
    validate_format(changeset, field, ~r/^https?:\/\/.+/, message: "must be a valid URL")
  end

  @doc """
  Validates that a field is a valid UUID format.
  """
  def validate_uuid(changeset, field) do
    validate_format(changeset, field, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, message: "must be a valid UUID")
  end

  @doc """
  Validates that a field is a valid IBAN format.
  """
  def validate_iban(changeset, field) do
    validate_format(changeset, field, ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]?){0,16}$/, message: "must be a valid IBAN")
  end

  @doc """
  Validates that a field is a valid SWIFT/BIC code format.
  """
  def validate_swift(changeset, field) do
    validate_format(changeset, field, ~r/^[A-Z]{6}[A-Z2-9][A-NP-Z0-9]([A-Z0-9]{3})?$/, message: "must be a valid SWIFT/BIC code")
  end

  @doc """
  Validates that a field is a valid credit card number format.
  """
  def validate_credit_card(changeset, field) do
    validate_format(changeset, field, ~r/^[0-9]{13,19}$/, message: "must be a valid credit card number")
  end

  @doc """
  Validates that a field is a valid currency code format.
  """
  def validate_currency(changeset, field) do
    validate_format(changeset, field, ~r/^[A-Z]{3}$/, message: "must be a valid 3-letter currency code")
  end

  @doc """
  Validates that a field is a valid country code format.
  """
  def validate_country_code(changeset, field) do
    validate_format(changeset, field, ~r/^[A-Z]{2}$/, message: "must be a valid 2-letter country code")
  end

  @doc """
  Validates that a field is a valid date format (YYYY-MM-DD).
  """
  def validate_date(changeset, field) do
    validate_format(changeset, field, ~r/^\d{4}-\d{2}-\d{2}$/, message: "must be a valid date (YYYY-MM-DD)")
  end

  @doc """
  Validates that a field is a valid datetime format (ISO8601).
  """
  def validate_datetime(changeset, field) do
    validate_format(changeset, field, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?$/, message: "must be a valid datetime (ISO8601)")
  end

  @doc """
  Validates that a field is a valid time format (HH:MM:SS).
  """
  def validate_time(changeset, field) do
    validate_format(changeset, field, ~r/^\d{2}:\d{2}:\d{2}$/, message: "must be a valid time (HH:MM:SS)")
  end

  @doc """
  Validates that a field is a valid postal code format.
  """
  def validate_postal_code(changeset, field) do
    validate_format(changeset, field, ~r/^[A-Z0-9\s\-]{3,10}$/i, message: "must be a valid postal code")
  end

  @doc """
  Validates that a field is a valid IP address format.
  """
  def validate_ip_address(changeset, field) do
    validate_format(changeset, field, ~r/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/, message: "must be a valid IP address")
  end

  @doc """
  Validates that a field is a valid MAC address format.
  """
  def validate_mac_address(changeset, field) do
    validate_format(changeset, field, ~r/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/, message: "must be a valid MAC address")
  end
end

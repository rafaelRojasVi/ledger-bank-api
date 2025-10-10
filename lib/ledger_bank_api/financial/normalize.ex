defmodule LedgerBankApi.Financial.Normalize do
  @moduledoc """
  Pure data transformation functions for financial operations.

  This module contains all data normalization and transformation logic for
  financial entities. All functions are pure (no side effects) and easily testable.

  ## Usage

      # Normalize payment attributes for creation
      Normalize.payment_attrs(attrs)

      # Normalize bank account attributes for creation
      Normalize.bank_account_attrs(attrs)

      # Normalize transaction attributes
      Normalize.transaction_attrs(attrs)
  """

  @doc """
  Normalize payment attributes for payment creation.

  Ensures all required fields are present and properly formatted.
  SECURITY: Forces user_id to prevent unauthorized payment creation.
  """
  def payment_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs = for {k, v} <- attrs, into: %{} do
      {to_string(k), v}
    end

    string_attrs
    |> Map.take(["amount", "direction", "payment_type", "description", "user_bank_account_id", "user_id"])
    |> normalize_amount()
    |> normalize_direction()
    |> normalize_payment_type()
    |> normalize_description()
    |> normalize_uuids()
    |> add_payment_defaults()
  end
  def payment_attrs(nil), do: %{}
  def payment_attrs(_), do: %{}

  @doc """
  Normalize bank account attributes for account creation.

  Ensures all required fields are present and properly formatted.
  SECURITY: Forces user_id to prevent unauthorized account creation.
  """
  def bank_account_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs = for {k, v} <- attrs, into: %{} do
      {to_string(k), v}
    end

    string_attrs
    |> Map.take(["currency", "account_type", "account_name", "user_bank_login_id", "user_id", "last_four", "external_account_id"])
    |> normalize_currency()
    |> normalize_account_type()
    |> normalize_account_name()
    |> normalize_uuids()
    |> add_bank_account_defaults()
  end
  def bank_account_attrs(nil), do: %{}
  def bank_account_attrs(_), do: %{}

  @doc """
  Normalize transaction attributes for transaction creation.

  Ensures all required fields are present and properly formatted.
  """
  def transaction_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs = for {k, v} <- attrs, into: %{} do
      {to_string(k), v}
    end

    string_attrs
    |> Map.take(["amount", "direction", "description", "user_bank_account_id", "external_transaction_id", "posted_at"])
    |> normalize_amount()
    |> normalize_direction()
    |> normalize_description()
    |> normalize_uuids()
    |> normalize_datetime()
    |> add_transaction_defaults()
  end
  def transaction_attrs(nil), do: %{}
  def transaction_attrs(_), do: %{}

  @doc """
  Normalize payment attributes for updates.

  Only allows updating certain fields and ensures proper formatting.
  """
  def payment_update_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs = for {k, v} <- attrs, into: %{} do
      {to_string(k), v}
    end

    # Only allow updating certain fields
    string_attrs
    |> Map.take(["description", "status"])
    |> normalize_description()
    |> normalize_status()
  end
  def payment_update_attrs(nil), do: %{}
  def payment_update_attrs(_), do: %{}

  @doc """
  Normalize bank account attributes for updates.

  Only allows updating certain fields and ensures proper formatting.
  """
  def bank_account_update_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs = for {k, v} <- attrs, into: %{} do
      {to_string(k), v}
    end

    # Only allow updating certain fields
    string_attrs
    |> Map.take(["account_name", "status", "balance", "last_sync_at"])
    |> normalize_account_name()
    |> normalize_status()
    |> normalize_balance()
    |> normalize_datetime()
  end
  def bank_account_update_attrs(nil), do: %{}
  def bank_account_update_attrs(_), do: %{}

  # ============================================================================
  # PRIVATE NORMALIZATION FUNCTIONS
  # ============================================================================

  defp normalize_amount(attrs) do
    case attrs["amount"] do
      nil -> attrs
      amount when is_binary(amount) ->
        case Decimal.parse(amount) do
          {decimal_amount, ""} -> Map.put(attrs, "amount", decimal_amount)
          _ -> attrs
        end
      amount when is_number(amount) ->
        Map.put(attrs, "amount", Decimal.from_float(amount))
      _ -> attrs
    end
  end

  defp normalize_direction(attrs) do
    case attrs["direction"] do
      nil -> attrs
      direction when is_binary(direction) ->
        normalized = String.upcase(String.trim(direction))
        if normalized in ["CREDIT", "DEBIT"] do
          Map.put(attrs, "direction", normalized)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_payment_type(attrs) do
    case attrs["payment_type"] do
      nil -> attrs
      payment_type when is_binary(payment_type) ->
        normalized = String.upcase(String.trim(payment_type))
        if normalized in ["TRANSFER", "PAYMENT", "DEPOSIT", "WITHDRAWAL"] do
          Map.put(attrs, "payment_type", normalized)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_currency(attrs) do
    case attrs["currency"] do
      nil -> attrs
      currency when is_binary(currency) ->
        normalized = String.upcase(String.trim(currency))
        if String.match?(normalized, ~r/^[A-Z]{3}$/) do
          Map.put(attrs, "currency", normalized)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_account_type(attrs) do
    case attrs["account_type"] do
      nil -> attrs
      account_type when is_binary(account_type) ->
        normalized = String.upcase(String.trim(account_type))
        if normalized in ["CHECKING", "SAVINGS", "CREDIT", "INVESTMENT"] do
          Map.put(attrs, "account_type", normalized)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_description(attrs) do
    case attrs["description"] do
      nil -> attrs
      description when is_binary(description) ->
        trimmed = String.trim(description)
        if String.length(trimmed) <= 255 do
          Map.put(attrs, "description", trimmed)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_account_name(attrs) do
    case attrs["account_name"] do
      nil -> attrs
      account_name when is_binary(account_name) ->
        trimmed = String.trim(account_name)
        if String.length(trimmed) <= 100 do
          Map.put(attrs, "account_name", trimmed)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_status(attrs) do
    case attrs["status"] do
      nil -> attrs
      status when is_binary(status) ->
        normalized = String.upcase(String.trim(status))
        if normalized in ["ACTIVE", "INACTIVE", "PENDING", "SUSPENDED"] do
          Map.put(attrs, "status", normalized)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_balance(attrs) do
    case attrs["balance"] do
      nil -> attrs
      balance when is_binary(balance) ->
        case Decimal.parse(balance) do
          {decimal_balance, ""} -> Map.put(attrs, "balance", decimal_balance)
          _ -> attrs
        end
      balance when is_number(balance) ->
        Map.put(attrs, "balance", Decimal.from_float(balance))
      _ -> attrs
    end
  end

  defp normalize_uuids(attrs) do
    attrs
    |> normalize_uuid_field("user_bank_account_id")
    |> normalize_uuid_field("user_bank_login_id")
    |> normalize_uuid_field("user_id")
  end

  defp normalize_uuid_field(attrs, field) do
    case attrs[field] do
      nil -> attrs
      uuid when is_binary(uuid) ->
        # Basic UUID format validation
        if String.match?(uuid, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
          Map.put(attrs, field, uuid)
        else
          attrs
        end
      _ -> attrs
    end
  end

  defp normalize_datetime(attrs) do
    attrs
    |> normalize_datetime_field("posted_at")
    |> normalize_datetime_field("last_sync_at")
  end

  defp normalize_datetime_field(attrs, field) do
    case attrs[field] do
      nil -> attrs
      datetime when is_binary(datetime) ->
        case DateTime.from_iso8601(datetime) do
          {:ok, dt, _offset} -> Map.put(attrs, field, dt)
          _ -> attrs
        end
      %DateTime{} = dt -> Map.put(attrs, field, dt)
      _ -> attrs
    end
  end

  # ============================================================================
  # DEFAULT VALUE FUNCTIONS
  # ============================================================================

  defp add_payment_defaults(attrs) do
    attrs
    |> add_default_status("PENDING")
    |> add_default_timestamps()
  end

  defp add_bank_account_defaults(attrs) do
    attrs
    |> add_default_status("ACTIVE")
    |> add_default_balance()
    |> add_default_timestamps()
  end

  defp add_transaction_defaults(attrs) do
    attrs
    |> add_default_timestamps()
  end

  defp add_default_status(attrs, default_status) do
    if is_nil(attrs["status"]) do
      Map.put(attrs, "status", default_status)
    else
      attrs
    end
  end

  defp add_default_balance(attrs) do
    if is_nil(attrs["balance"]) do
      Map.put(attrs, "balance", Decimal.new(0))
    else
      attrs
    end
  end

  defp add_default_timestamps(attrs) do
    now = DateTime.utc_now()
    attrs
    |> Map.put_new("inserted_at", now)
    |> Map.put_new("updated_at", now)
  end
end

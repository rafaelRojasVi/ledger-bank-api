defmodule LedgerBankApi.Database.ValidationMacros do
  @moduledoc """
  Macros for common validation patterns to reduce code repetition in schemas.
  """

  import Ecto.Changeset

  @doc """
  Macro to generate common validation functions for schemas.

  Usage:
    use_common_validations()
  """
  defmacro use_common_validations do
    quote do
      @doc """
      Validates country code format (2-letter ISO code).
      """
      def validate_country_code(changeset) do
        validate_format(changeset, :country, ~r/^[A-Z]{2}$/,
          message: "must be a valid 2-letter country code (e.g., US, UK)")
      end

      @doc """
      Validates name length (2-100 characters).
      """
      def validate_name_length(changeset) do
        validate_length(changeset, :name, min: 2, max: 100)
      end

      @doc """
      Validates URL format (http/https).
      """
      def validate_url_format(changeset) do
        url = get_change(changeset, :url)
        if is_nil(url) or url == "" do
          changeset
        else
          validate_format(changeset, :url, ~r/^https?:\/\/.+/,
            message: "must be a valid URL starting with http:// or https://")
        end
      end

      @doc """
      Validates logo URL format (http/https).
      """
      def validate_logo_url_format(changeset) do
        logo_url = get_change(changeset, :logo_url)
        if is_nil(logo_url) or logo_url == "" do
          changeset
        else
          validate_format(changeset, :logo_url, ~r/^https?:\/\/.+/,
            message: "must be a valid URL starting with http:// or https://")
        end
      end

      @doc """
      Validates API endpoint URL format (http/https).
      """
      def validate_api_endpoint_format(changeset) do
        api_endpoint = get_change(changeset, :api_endpoint)
        if is_nil(api_endpoint) or api_endpoint == "" do
          changeset
        else
          validate_format(changeset, :api_endpoint, ~r/^https?:\/\/.+/,
            message: "must be a valid URL starting with http:// or https://")
        end
      end

      @doc """
      Validates that amount is positive (not negative).
      """
      def validate_amount_positive(changeset) do
        amount = get_change(changeset, :amount)
        if is_nil(amount) do
          changeset
        else
          if Decimal.lt?(amount, Decimal.new(0)) do
            add_error(changeset, :amount, "cannot be negative")
          else
            changeset
          end
        end
      end

      @doc """
      Validates description length (max 500 characters).
      """
      def validate_description_length(changeset) do
        description = get_change(changeset, :description)
        if is_nil(description) or description == "" do
          changeset
        else
          validate_length(changeset, :description, max: 500)
        end
      end

      @doc """
      Validates email format.
      """
      def validate_email_format(changeset) do
        validate_format(changeset, :email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
          message: "must be a valid email address")
      end

      @doc """
      Validates currency format (3-letter ISO code).
      """
      def validate_currency_format(changeset) do
        validate_format(changeset, :currency, ~r/^[A-Z]{3}$/,
          message: "must be a valid 3-letter currency code (e.g., USD, EUR)")
      end

      @doc """
      Validates last four digits format (exactly 4 digits).
      """
      def validate_last_four_format(changeset) do
        last_four = get_change(changeset, :last_four)
        if is_nil(last_four) or last_four == "" do
          changeset
        else
          validate_format(changeset, :last_four, ~r/^\d{4}$/,
            message: "must be exactly 4 digits")
        end
      end

      @doc """
      Validates IBAN format.
      """
      def validate_iban_format(changeset) do
        iban = get_change(changeset, :iban)
        if is_nil(iban) or iban == "" do
          changeset
        else
          validate_format(changeset, :iban, ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]?){0,16}$/,
            message: "must be a valid IBAN format")
        end
      end

      @doc """
      Validates SWIFT/BIC code format.
      """
      def validate_swift_format(changeset) do
        swift_code = get_change(changeset, :swift_code)
        if is_nil(swift_code) or swift_code == "" do
          changeset
        else
          validate_format(changeset, :swift_code, ~r/^[A-Z]{6}[A-Z2-9][A-NP-Z0-9]([A-Z0-9]{3})?$/,
            message: "must be a valid SWIFT/BIC code format")
        end
      end

      @doc """
      Validates routing number format (exactly 9 digits).
      """
      def validate_routing_number_format(changeset) do
        routing_number = get_change(changeset, :routing_number)
        if is_nil(routing_number) or routing_number == "" do
          changeset
        else
          validate_format(changeset, :routing_number, ~r/^\d{9}$/,
            message: "must be exactly 9 digits")
        end
      end

      @doc """
      Validates that posted_at is not in the future.
      """
      def validate_posted_at_not_future(changeset) do
        posted_at = get_change(changeset, :posted_at)
        if is_nil(posted_at) do
          changeset
        else
          if DateTime.compare(posted_at, DateTime.utc_now()) == :gt do
            add_error(changeset, :posted_at, "cannot be in the future")
          else
            changeset
          end
        end
      end

      @doc """
      Validates that last_sync_at is not in the future.
      """
      def validate_last_sync_at_not_future(changeset) do
        last_sync_at = get_change(changeset, :last_sync_at)
        if is_nil(last_sync_at) do
          changeset
        else
          if DateTime.compare(last_sync_at, DateTime.utc_now()) == :gt do
            add_error(changeset, :last_sync_at, "cannot be in the future")
          else
            changeset
          end
        end
      end

      @doc """
      Validates OAuth2 scope format.
      """
      def validate_oauth2_scope_format(changeset) do
        scope = get_change(changeset, :scope)
        if is_nil(scope) or scope == "" do
          changeset
        else
          if String.match?(scope, ~r/^[a-zA-Z0-9_:\-\.]+(\s+[a-zA-Z0-9_:\-\.]+)*$/) do
            changeset
          else
            add_error(changeset, :scope, "must be valid OAuth2 scopes separated by spaces")
          end
        end
      end

      @doc """
      Validates external account ID format.
      """
      def validate_external_account_id_format(changeset) do
        external_account_id = get_change(changeset, :external_account_id)
        if is_nil(external_account_id) or external_account_id == "" do
          changeset
        else
          if String.match?(external_account_id, ~r/^[a-zA-Z0-9\-_]+$/) do
            changeset
          else
            add_error(changeset, :external_account_id,
              "must contain only letters, numbers, hyphens, and underscores")
          end
        end
      end

      @doc """
      Validates account name length (1-100 characters).
      """
      def validate_account_name_length(changeset) do
        validate_length(changeset, :account_name, min: 1, max: 100)
      end

      @doc """
      Validates username format (3-50 characters).
      """
      def validate_username_format(changeset) do
        username = get_change(changeset, :username)
        if is_nil(username) or username == "" do
          changeset
        else
          validate_length(changeset, :username, min: 3, max: 50)
        end
      end

      @doc """
      Validates sync frequency (300-86400 seconds).
      """
      def validate_sync_frequency(changeset) do
        sync_frequency = get_change(changeset, :sync_frequency)
        if is_nil(sync_frequency) do
          changeset
        else
          if sync_frequency < 300 or sync_frequency > 86400 do
            add_error(changeset, :sync_frequency,
              "must be between 300 (5 minutes) and 86400 (24 hours) seconds")
          else
            changeset
          end
        end
      end
    end
  end

  @doc """
  Macro to generate common changeset patterns.

  Usage:
    use_common_changesets()
  """
  defmacro use_common_changesets do
    quote do
      @doc """
      Base changeset with common validations.
      """
      def base_changeset(struct, attrs) do
        struct
        |> cast(attrs, @fields)
        |> validate_required(@required_fields)
      end

      @doc """
      Changeset for updates (without changing critical fields).
      """
      def update_changeset(struct, attrs) do
        struct
        |> cast(attrs, @update_fields)
        |> validate_required(@update_required_fields)
      end
    end
  end
end

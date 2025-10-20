defmodule LedgerBankApiWeb.Validation.InputValidator do
  @moduledoc """
  Web layer input validation for controllers.

  ## Architecture Role

  This module serves as the **web layer validation bridge** between HTTP requests and business logic.
  It provides consistent error formatting for API responses and handles web-specific validation concerns.

  ## Responsibilities

  - **Web Layer Validation**: Validates HTTP request parameters and body data
  - **Error Formatting**: Converts validation errors to proper Error structs for API responses
  - **Field Mapping**: Maps HTTP field names to internal field names
  - **Context Building**: Adds web-specific context (source, action) to errors
  - **Parameter Extraction**: Extracts and validates pagination, sorting, and filtering parameters

  ## Usage

      # In controllers
      with {:ok, validated_params} <- InputValidator.validate_user_creation(params),
           {:ok, user} <- UserService.create_user(validated_params) do
        handle_success(conn, user)
      else
        error -> handle_standard_errors(conn, context).(error)
      end

  ## Layer Separation

  - **InputValidator** (this module): Web layer validation with error formatting
  - **Core Validator**: Data format validation (used internally)
  - **Schema Validation**: Ecto changeset validation for database operations
  - **Service Layer**: Business logic validation (permissions, role-based rules)

  ## Design Principles

  - **No duplication**: Uses core Validator for validation logic
  - **Consistent errors**: All errors go through ErrorHandler.business_error
  - **Web-specific**: Handles web layer concerns like field names and context
  """

  alias LedgerBankApi.Core.{ErrorHandler, Validator}

  # ============================================================================
  # USER VALIDATION
  # ============================================================================

  @doc """
  Validates user creation parameters with consistent error format (public registration).

  SECURITY: Does NOT validate or pass role parameter - role is forced to "user" at normalization layer.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_user_creation(params) do
    context = %{source: "input_validator", action: :user_creation}

    # Note: We default to "user" role for password validation, but actual role
    # assignment happens in Normalize.user_attrs which forces role to "user"
    with {:ok, email} <- validate_email(params["email"], context),
         {:ok, full_name} <- validate_full_name(params["full_name"], context),
         {:ok, password} <- validate_password(params["password"], context, "user"),
         {:ok, password_confirmation} <-
           validate_password_confirmation(params["password_confirmation"], context),
         :ok <- validate_password_match(password, password_confirmation, context) do
      {:ok,
       %{
         email: email,
         full_name: full_name,
         password: password,
         password_confirmation: password_confirmation
         # NOTE: No role in output - forced to "user" in Normalize.user_attrs
       }}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Validates admin user creation parameters with consistent error format.

  SECURITY: Allows role selection but should only be called from admin-protected endpoints.
  The actual authorization check happens in UserService.create_user_as_admin.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_admin_user_creation(params) do
    context = %{source: "input_validator", action: :admin_user_creation}

    with {:ok, email} <- validate_email(params["email"], context),
         {:ok, full_name} <- validate_full_name(params["full_name"], context),
         {:ok, role} <- validate_role(params["role"] || "user", context),
         {:ok, password} <- validate_password(params["password"], context, role),
         {:ok, password_confirmation} <-
           validate_password_confirmation(params["password_confirmation"], context),
         :ok <- validate_password_match(password, password_confirmation, context) do
      {:ok,
       %{
         email: email,
         full_name: full_name,
         password: password,
         password_confirmation: password_confirmation,
         role: role
       }}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Validates user update parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_user_update(params) do
    context = %{source: "input_validator", action: :user_update}

    with {:ok, validated_fields} <- validate_user_update_fields(params, context) do
      if map_size(validated_fields) == 0 do
        {:error,
         ErrorHandler.business_error(
           :missing_fields,
           Map.put(context, :message, "At least one field must be provided for update")
         )}
      else
        {:ok, validated_fields}
      end
    end
  end

  defp validate_user_update_fields(params, context) do
    validated_fields = %{}

    case maybe_validate_field(
           validated_fields,
           :email,
           params["email"],
           &validate_email/2,
           context
         ) do
      {:error, error} ->
        {:error, error}

      validated_fields ->
        case maybe_validate_field(
               validated_fields,
               :full_name,
               params["full_name"],
               &validate_full_name/2,
               context
             ) do
          {:error, error} ->
            {:error, error}

          validated_fields ->
            case maybe_validate_field(
                   validated_fields,
                   :role,
                   params["role"],
                   &validate_role/2,
                   context
                 ) do
              {:error, error} ->
                {:error, error}

              validated_fields ->
                case maybe_validate_field(
                       validated_fields,
                       :status,
                       params["status"],
                       &validate_status/2,
                       context
                     ) do
                  {:error, error} -> {:error, error}
                  validated_fields -> {:ok, validated_fields}
                end
            end
        end
    end
  end

  @doc """
  Validates password change parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_password_change(params, user_role \\ "user") do
    context = %{source: "input_validator", action: :password_change}

    with {:ok, current_password} <-
           validate_current_password(params["current_password"], context),
         {:ok, new_password} <- validate_password(params["new_password"], context, user_role),
         {:ok, password_confirmation} <-
           validate_password_confirmation(params["password_confirmation"], context),
         :ok <- validate_password_match(new_password, password_confirmation, context) do
      {:ok,
       %{
         current_password: current_password,
         # Map new_password to password for schema
         password: new_password,
         password_confirmation: password_confirmation
       }}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Validates login parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_login(params) do
    context = %{source: "input_validator", action: :login}

    # Check email first - empty email should return missing_fields (400)
    case validate_email(params["email"], context) do
      {:ok, email} ->
        # Email is valid, now check password - empty password should return invalid_credentials (401)
        case validate_password(params["password"], context, "user") do
          {:ok, password} -> {:ok, %{email: email, password: password}}
          {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
        end

      {:error, %LedgerBankApi.Core.Error{} = error} ->
        {:error, error}
    end
  end

  @doc """
  Validates refresh token parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_refresh_token(params) do
    context = %{source: "input_validator", action: :refresh_token}

    case params["refresh_token"] do
      refresh_token when is_binary(refresh_token) and byte_size(refresh_token) > 0 ->
        {:ok, %{refresh_token: refresh_token}}

      _ ->
        {:error,
         ErrorHandler.business_error(
           :missing_fields,
           Map.put(context, :field, "refresh_token")
           |> Map.put(:message, "Refresh token is required and must be a non-empty string")
         )}
    end
  end

  @doc """
  Validates access token from Authorization header.
  Returns {:ok, token} or {:error, %Error{}}.
  """
  def validate_access_token(token) when is_binary(token) do
    if byte_size(token) > 0 do
      {:ok, token}
    else
      context = %{source: "input_validator", action: :access_token}

      {:error,
       ErrorHandler.business_error(
         :invalid_token,
         Map.put(context, :message, "Access token cannot be empty")
       )}
    end
  end

  def validate_access_token(nil) do
    context = %{source: "input_validator", action: :access_token}

    {:error,
     ErrorHandler.business_error(
       :invalid_token,
       Map.put(context, :message, "Access token is required")
     )}
  end

  def validate_access_token(_) do
    context = %{source: "input_validator", action: :access_token}

    {:error,
     ErrorHandler.business_error(
       :invalid_token,
       Map.put(context, :message, "Access token must be a string")
     )}
  end

  @doc """
  Validates user ID parameter.
  Returns {:ok, user_id} or {:error, %Error{}}.
  """
  def validate_user_id(user_id) do
    context = %{source: "input_validator", action: :user_id}

    case Validator.validate_uuid(user_id) do
      :ok ->
        {:ok, user_id}

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "user_id"))}
    end
  end

  @doc """
  Validates UUID parameters with consistent error format.
  Returns {:ok, uuid} or {:error, %Error{}}.
  """
  def validate_uuid(uuid, context \\ %{source: "input_validator"}) do
    case Validator.validate_uuid(uuid) do
      :ok ->
        {:ok, uuid}

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "uuid"))}
    end
  end

  # ============================================================================
  # PARAMETER EXTRACTION WITH VALIDATION
  # ============================================================================

  @doc """
  Extract and validate pagination parameters with consistent error format.
  """
  def extract_pagination_params(params, _context \\ %{source: "input_validator"}) do
    page =
      case Integer.parse(params["page"] || "1") do
        {page, ""} when page >= 1 -> page
        _ -> 1
      end

    page_size =
      case Integer.parse(params["page_size"] || "20") do
        {page_size, ""} when page_size >= 1 and page_size <= 100 -> page_size
        {page_size, ""} when page_size > 100 -> 100
        _ -> 20
      end

    {:ok, %{page: page, page_size: page_size}}
  end

  @doc """
  Extract and validate sorting parameters with consistent error format.
  """
  def extract_sort_params(params, _context \\ %{source: "input_validator"}) do
    case Map.get(params, "sort") do
      nil ->
        {:ok, []}

      sort_string when is_binary(sort_string) ->
        sort_fields =
          sort_string
          |> String.split(",")
          |> Enum.map(&parse_sort_field/1)
          |> Enum.reject(&is_nil/1)

        {:ok, sort_fields}

      _ ->
        {:ok, []}
    end
  end

  @doc """
  Extract and validate filter parameters with consistent error format.
  """
  def extract_filter_params(params, _context \\ %{source: "input_validator"}) do
    filters =
      params
      |> Map.drop(["page", "page_size", "sort"])
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        if is_binary(value) and String.length(value) > 0 do
          Map.put(acc, String.to_atom(key), value)
        else
          acc
        end
      end)

    {:ok, filters}
  end

  # ============================================================================
  # FINANCIAL VALIDATION
  # ============================================================================

  @doc """
  Validates payment creation parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_payment_creation(params) do
    context = %{source: "input_validator", action: :payment_creation}

    with {:ok, amount} <- validate_amount(params["amount"], context),
         {:ok, direction} <- validate_direction(params["direction"], context),
         {:ok, payment_type} <- validate_payment_type(params["payment_type"], context),
         {:ok, description} <- validate_description(params["description"], context),
         {:ok, user_bank_account_id} <- validate_uuid(params["user_bank_account_id"], context) do
      {:ok,
       %{
         amount: amount,
         direction: direction,
         payment_type: payment_type,
         description: description,
         user_bank_account_id: user_bank_account_id
       }}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Validates bank account creation parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_bank_account_creation(params) do
    context = %{source: "input_validator", action: :bank_account_creation}

    with {:ok, currency} <- validate_currency(params["currency"], context),
         {:ok, account_type} <- validate_account_type(params["account_type"], context),
         {:ok, account_name} <- validate_account_name(params["account_name"], context),
         {:ok, user_bank_login_id} <- validate_uuid(params["user_bank_login_id"], context) do
      {:ok,
       %{
         currency: currency,
         account_type: account_type,
         account_name: account_name,
         user_bank_login_id: user_bank_login_id,
         last_four: params["last_four"],
         external_account_id: params["external_account_id"]
       }}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Validates payment filter parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_payment_filters(params) do
    context = %{source: "input_validator", action: :payment_filters}

    with {:ok, pagination} <- extract_pagination_params(params, context),
         {:ok, direction} <- maybe_validate_direction(params["direction"], context),
         {:ok, status} <- maybe_validate_payment_status(params["status"], context),
         {:ok, payment_type} <- maybe_validate_payment_type(params["payment_type"], context),
         {:ok, date_from} <- maybe_validate_date(params["date_from"], context),
         {:ok, date_to} <- maybe_validate_date(params["date_to"], context) do
      validated_params =
        pagination
        |> maybe_put(:direction, direction)
        |> maybe_put(:status, status)
        |> maybe_put(:payment_type, payment_type)
        |> maybe_put(:date_from, date_from)
        |> maybe_put(:date_to, date_to)

      {:ok, validated_params}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
    end
  end

  @doc """
  Validates transaction filter parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_transaction_filters(params) do
    context = %{source: "input_validator", action: :transaction_filters}

    with {:ok, direction} <- maybe_validate_direction(params["direction"], context),
         {:ok, date_from} <- maybe_validate_date(params["date_from"], context),
         {:ok, date_to} <- maybe_validate_date(params["date_to"], context) do
      filters =
        %{}
        |> maybe_put(:direction, direction)
        |> maybe_put(:date_from, date_from)
        |> maybe_put(:date_to, date_to)

      {:ok, filters}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
    end
  end

  # ============================================================================
  # PRIVATE VALIDATION FUNCTIONS
  # ============================================================================

  defp validate_email(email, context) do
    case Validator.validate_email(email) do
      :ok ->
        {:ok, email}

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "email"))}
    end
  end

  defp validate_full_name(full_name, context) do
    case Validator.validate_required(full_name) do
      :ok ->
        # Additional length validation for names
        if String.length(full_name) > 255 do
          {:error,
           ErrorHandler.business_error(
             :invalid_name_format,
             Map.put(context, :field, "full_name")
             |> Map.put(:message, "Full name cannot exceed 255 characters")
           )}
        else
          {:ok, full_name}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "full_name"))}
    end
  end

  defp validate_password(password, context, role) do
    case Validator.validate_password(password) do
      :ok ->
        # Additional role-based length validation
        min_length = if role in ["admin", "support"], do: 15, else: 8

        if String.length(password) < min_length do
          {:error,
           ErrorHandler.business_error(
             :invalid_password_format,
             Map.put(context, :field, "password")
             |> Map.put(:message, "Password must be at least #{min_length} characters long")
           )}
        else
          {:ok, password}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "password"))}
    end
  end

  defp validate_password_confirmation(password_confirmation, context) do
    case Validator.validate_password(password_confirmation) do
      :ok ->
        {:ok, password_confirmation}

      {:error, reason} ->
        {:error,
         ErrorHandler.business_error(reason, Map.put(context, :field, "password_confirmation"))}
    end
  end

  defp validate_current_password(current_password, context) do
    case Validator.validate_password(current_password) do
      :ok ->
        {:ok, current_password}

      {:error, reason} ->
        {:error,
         ErrorHandler.business_error(reason, Map.put(context, :field, "current_password"))}
    end
  end

  defp validate_role(role, context) when is_binary(role) do
    if role in ["user", "admin", "support"] do
      {:ok, role}
    else
      {:error,
       ErrorHandler.business_error(
         :invalid_role,
         Map.put(context, :field, "role")
         |> Map.put(:value, role)
         |> Map.put(:message, "Role must be one of: user, admin, support")
       )}
    end
  end

  defp validate_role(_, context) do
    {:error,
     ErrorHandler.business_error(
       :invalid_role,
       Map.put(context, :field, "role") |> Map.put(:message, "Role must be a string")
     )}
  end

  defp validate_status(status, context) when is_binary(status) do
    if status in ["ACTIVE", "SUSPENDED", "DELETED"] do
      {:ok, status}
    else
      {:error,
       ErrorHandler.business_error(
         :invalid_status,
         Map.put(context, :field, "status")
         |> Map.put(:value, status)
         |> Map.put(:message, "Status must be one of: ACTIVE, SUSPENDED, DELETED")
       )}
    end
  end

  defp validate_status(_, context) do
    {:error,
     ErrorHandler.business_error(
       :invalid_status,
       Map.put(context, :field, "status") |> Map.put(:message, "Status must be a string")
     )}
  end

  defp validate_password_match(password, password_confirmation, context) do
    if password == password_confirmation do
      :ok
    else
      {:error,
       ErrorHandler.business_error(
         :invalid_password_format,
         Map.put(context, :message, "Password confirmation does not match")
       )}
    end
  end

  defp maybe_validate_field(map, field, value, validator_fun, context) do
    if value do
      case validator_fun.(value, context) do
        {:ok, validated_value} ->
          Map.put(map, field, validated_value)

        {:error, %LedgerBankApi.Core.Error{} = error} ->
          # Return the error immediately - this will be caught by the calling function
          {:error, error}
      end
    else
      map
    end
  end

  defp parse_sort_field(field_string) do
    case String.split(field_string, ":") do
      [field] ->
        {String.to_atom(field), :asc}

      [field, direction] when direction in ["asc", "desc"] ->
        {String.to_atom(field), String.to_atom(direction)}

      _ ->
        nil
    end
  end

  # ============================================================================
  # FINANCIAL PRIVATE VALIDATION FUNCTIONS
  # ============================================================================

  defp validate_amount(amount, context) do
    case Validator.validate_required(amount) do
      :ok ->
        case Decimal.parse(amount) do
          {decimal_amount, ""} ->
            if Decimal.gt?(decimal_amount, Decimal.new(0)) do
              {:ok, decimal_amount}
            else
              {:error,
               ErrorHandler.business_error(:negative_amount, Map.put(context, :field, "amount"))}
            end

          _ ->
            {:error,
             ErrorHandler.business_error(
               :invalid_amount_format,
               Map.put(context, :field, "amount")
             )}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "amount"))}
    end
  end

  defp validate_direction(direction, context) do
    case Validator.validate_required(direction) do
      :ok ->
        normalized_direction = String.upcase(String.trim(direction))

        if normalized_direction in ["CREDIT", "DEBIT"] do
          {:ok, normalized_direction}
        else
          {:error,
           ErrorHandler.business_error(:invalid_direction, Map.put(context, :field, "direction"))}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "direction"))}
    end
  end

  defp validate_payment_type(payment_type, context) do
    case Validator.validate_required(payment_type) do
      :ok ->
        normalized_type = String.upcase(String.trim(payment_type))

        if normalized_type in ["TRANSFER", "PAYMENT", "DEPOSIT", "WITHDRAWAL"] do
          {:ok, normalized_type}
        else
          {:error,
           ErrorHandler.business_error(
             :invalid_payment_type,
             Map.put(context, :field, "payment_type")
           )}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "payment_type"))}
    end
  end

  defp validate_currency(currency, context) do
    case Validator.validate_required(currency) do
      :ok ->
        normalized_currency = String.upcase(String.trim(currency))

        if String.match?(normalized_currency, ~r/^[A-Z]{3}$/) do
          {:ok, normalized_currency}
        else
          {:error,
           ErrorHandler.business_error(
             :invalid_currency_format,
             Map.put(context, :field, "currency")
           )}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "currency"))}
    end
  end

  defp validate_account_type(account_type, context) do
    case Validator.validate_required(account_type) do
      :ok ->
        normalized_type = String.upcase(String.trim(account_type))

        if normalized_type in ["CHECKING", "SAVINGS", "CREDIT", "INVESTMENT"] do
          {:ok, normalized_type}
        else
          {:error,
           ErrorHandler.business_error(
             :invalid_account_type,
             Map.put(context, :field, "account_type")
           )}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "account_type"))}
    end
  end

  defp validate_description(description, context) do
    case Validator.validate_required(description) do
      :ok ->
        if String.length(description) > 255 do
          {:error,
           ErrorHandler.business_error(
             :invalid_description_format,
             Map.put(context, :field, "description")
           )}
        else
          {:ok, String.trim(description)}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "description"))}
    end
  end

  defp validate_account_name(account_name, context) do
    case Validator.validate_required(account_name) do
      :ok ->
        if String.length(account_name) > 100 do
          {:error,
           ErrorHandler.business_error(
             :invalid_account_name_format,
             Map.put(context, :field, "account_name")
           )}
        else
          {:ok, String.trim(account_name)}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "account_name"))}
    end
  end

  # Optional validation functions (return :ok if nil)
  defp maybe_validate_direction(nil, _context), do: {:ok, nil}
  defp maybe_validate_direction(direction, context), do: validate_direction(direction, context)

  defp maybe_validate_payment_type(nil, _context), do: {:ok, nil}

  defp maybe_validate_payment_type(payment_type, context),
    do: validate_payment_type(payment_type, context)

  defp maybe_validate_payment_status(nil, _context), do: {:ok, nil}

  defp maybe_validate_payment_status(status, context) do
    case Validator.validate_required(status) do
      :ok ->
        normalized_status = String.upcase(String.trim(status))

        if normalized_status in ["PENDING", "COMPLETED", "FAILED", "CANCELLED"] do
          {:ok, normalized_status}
        else
          {:error,
           ErrorHandler.business_error(:invalid_status, Map.put(context, :field, "status"))}
        end

      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "status"))}
    end
  end

  defp maybe_validate_date(nil, _context), do: {:ok, nil}

  defp maybe_validate_date(date_string, context) do
    case DateTime.from_iso8601(date_string) do
      {:ok, _datetime, _offset} ->
        {:ok, date_string}

      _ ->
        {:error,
         ErrorHandler.business_error(:invalid_datetime_format, Map.put(context, :field, "date"))}
    end
  end

  # Helper function to conditionally add to map
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

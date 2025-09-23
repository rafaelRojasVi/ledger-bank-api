defmodule LedgerBankApiWeb.Validation.InputValidator do
  @moduledoc """
  Web layer input validation that provides consistent error formatting for controllers.

  This module serves as the bridge between core validation logic and web layer error handling.
  It uses the core Validator module for validation logic and converts results to proper Error structs.

  ## Architecture Role

  - **Purpose**: Web layer validation with proper error formatting for API responses
  - **Uses**: Core Validator module for validation logic
  - **Returns**: Proper Error structs via ErrorHandler.business_error
  - **Used by**: Controllers for parameter validation
  - **Error conversion**: Converts Validator error reasons to ErrorHandler.business_error calls

  ## Usage

      # In controllers
      with {:ok, validated_params} <- InputValidator.validate_user_creation(params),
           {:ok, user} <- UserService.create_user(validated_params) do
        handle_success(conn, user)
      else
        error -> handle_standard_errors(conn, context).(error)
      end

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
  Validates user creation parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_user_creation(params) do
    context = %{source: "input_validator", action: :user_creation}

    with {:ok, email} <- validate_email(params["email"], context),
         {:ok, full_name} <- validate_full_name(params["full_name"], context),
         {:ok, role} <- validate_role(params["role"], context),
         {:ok, password} <- validate_password(params["password"], context, role),
         {:ok, password_confirmation} <- validate_password_confirmation(params["password_confirmation"], context),
         :ok <- validate_password_match(password, password_confirmation, context) do
      {:ok, %{
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

    validated_fields = %{}
    |> maybe_validate_field(:email, params["email"], &validate_email/2, context)
    |> maybe_validate_field(:full_name, params["full_name"], &validate_full_name/2, context)
    |> maybe_validate_field(:role, params["role"], &validate_role/2, context)
    |> maybe_validate_field(:status, params["status"], &validate_status/2, context)

    if map_size(validated_fields) == 0 do
      {:error, ErrorHandler.business_error(:missing_fields, Map.put(context, :message, "At least one field must be provided for update"))}
    else
      {:ok, validated_fields}
    end
  end

  @doc """
  Validates password change parameters with consistent error format.
  Returns {:ok, validated_params} or {:error, %Error{}}.
  """
  def validate_password_change(params, user_role \\ "user") do
    context = %{source: "input_validator", action: :password_change}

    with {:ok, current_password} <- validate_current_password(params["current_password"], context),
         {:ok, new_password} <- validate_password(params["new_password"], context, user_role),
         {:ok, password_confirmation} <- validate_password_confirmation(params["password_confirmation"], context),
         :ok <- validate_password_match(new_password, password_confirmation, context) do
      {:ok, %{
        current_password: current_password,
        new_password: new_password,
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

    with {:ok, email} <- validate_email(params["email"], context),
         {:ok, password} <- validate_password(params["password"], context, "user") do
      {:ok, %{email: email, password: password}}
    else
      {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
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
        {:error, ErrorHandler.business_error(:missing_fields, Map.put(context, :field, "refresh_token") |> Map.put(:message, "Refresh token is required and must be a non-empty string"))}
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
      {:error, ErrorHandler.business_error(:invalid_token, Map.put(context, :message, "Access token cannot be empty"))}
    end
  end

  def validate_access_token(nil) do
    context = %{source: "input_validator", action: :access_token}
    {:error, ErrorHandler.business_error(:invalid_token, Map.put(context, :message, "Access token is required"))}
  end

  def validate_access_token(_) do
    context = %{source: "input_validator", action: :access_token}
    {:error, ErrorHandler.business_error(:invalid_token, Map.put(context, :message, "Access token must be a string"))}
  end

  @doc """
  Validates user ID parameter.
  Returns {:ok, user_id} or {:error, %Error{}}.
  """
  def validate_user_id(user_id) do
    context = %{source: "input_validator", action: :user_id}

    case Validator.validate_uuid(user_id) do
      :ok -> {:ok, user_id}
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
      :ok -> {:ok, uuid}
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
    page = case Integer.parse(params["page"] || "1") do
      {page, ""} when page >= 1 -> page
      _ -> 1
    end

    page_size = case Integer.parse(params["page_size"] || "20") do
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
      nil -> {:ok, []}
      sort_string when is_binary(sort_string) ->
        sort_fields = sort_string
        |> String.split(",")
        |> Enum.map(&parse_sort_field/1)
        |> Enum.reject(&is_nil/1)

        {:ok, sort_fields}
      _ -> {:ok, []}
    end
  end

  @doc """
  Extract and validate filter parameters with consistent error format.
  """
  def extract_filter_params(params, _context \\ %{source: "input_validator"}) do
    filters = params
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
  # PRIVATE VALIDATION FUNCTIONS
  # ============================================================================

  defp validate_email(email, context) do
    case Validator.validate_email(email) do
      :ok -> {:ok, email}
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "email"))}
    end
  end

  defp validate_full_name(full_name, context) do
    case Validator.validate_required(full_name) do
      :ok ->
        # Additional length validation for names
        if String.length(full_name) > 255 do
          {:error, ErrorHandler.business_error(:invalid_name_format, Map.put(context, :field, "full_name") |> Map.put(:message, "Full name cannot exceed 255 characters"))}
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
          {:error, ErrorHandler.business_error(:invalid_password_format, Map.put(context, :field, "password") |> Map.put(:message, "Password must be at least #{min_length} characters long"))}
        else
          {:ok, password}
        end
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "password"))}
    end
  end

  defp validate_password_confirmation(password_confirmation, context) do
    case Validator.validate_password(password_confirmation) do
      :ok -> {:ok, password_confirmation}
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "password_confirmation"))}
    end
  end

  defp validate_current_password(current_password, context) do
    case Validator.validate_password(current_password) do
      :ok -> {:ok, current_password}
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, Map.put(context, :field, "current_password"))}
    end
  end

  defp validate_role(role, context) when is_binary(role) do
    if role in ["user", "admin", "support"] do
      {:ok, role}
    else
      {:error, ErrorHandler.business_error(:invalid_direction, Map.put(context, :field, "role") |> Map.put(:value, role) |> Map.put(:message, "Role must be one of: user, admin, support"))}
    end
  end

  defp validate_role(_, context) do
    {:error, ErrorHandler.business_error(:invalid_direction, Map.put(context, :field, "role") |> Map.put(:message, "Role must be a string"))}
  end

  defp validate_status(status, context) when is_binary(status) do
    if status in ["ACTIVE", "SUSPENDED", "DELETED"] do
      {:ok, status}
    else
      {:error, ErrorHandler.business_error(:invalid_direction, Map.put(context, :field, "status") |> Map.put(:value, status) |> Map.put(:message, "Status must be one of: ACTIVE, SUSPENDED, DELETED"))}
    end
  end

  defp validate_status(_, context) do
    {:error, ErrorHandler.business_error(:invalid_direction, Map.put(context, :field, "status") |> Map.put(:message, "Status must be a string"))}
  end

  defp validate_password_match(password, password_confirmation, context) do
    if password == password_confirmation do
      :ok
    else
      {:error, ErrorHandler.business_error(:invalid_password_format, Map.put(context, :message, "Password confirmation does not match"))}
    end
  end

  defp maybe_validate_field(map, field, value, validator_fun, context) do
    if value do
      case validator_fun.(value, context) do
        {:ok, validated_value} -> Map.put(map, field, validated_value)
        {:error, %LedgerBankApi.Core.Error{} = error} ->
          # Return the error immediately - this will be caught by the calling function
          throw({:error, error})
      end
    else
      map
    end
  end

  defp parse_sort_field(field_string) do
    case String.split(field_string, ":") do
      [field] -> {String.to_atom(field), :asc}
      [field, direction] when direction in ["asc", "desc"] ->
        {String.to_atom(field), String.to_atom(direction)}
      _ -> nil
    end
  end
end

defmodule LedgerBankApi.Accounts.Normalize do
  @moduledoc """
  Pure data transformation functions for user operations.

  This module contains all data normalization and transformation logic.
  All functions are pure (no side effects) and easily testable.

  ## Usage

      # Normalize user attributes for creation
      Normalize.user_attrs(attrs)

      # Normalize user attributes for updates
      Normalize.user_update_attrs(attrs)

      # Normalize password attributes
      Normalize.password_attrs(attrs)
  """

  @doc """
  Normalize user attributes for user creation (public registration).

  Ensures all required fields are present and properly formatted.
  SECURITY: Forces role to "user" to prevent unauthorized admin creation.
  """
  def user_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs =
      for {k, v} <- attrs, into: %{} do
        {to_string(k), v}
      end

    string_attrs
    |> Map.take(["email", "full_name", "password", "password_confirmation"])
    |> normalize_email()
    |> normalize_full_name()
    |> add_defaults()
    # SECURITY: Always set role to "user" for public registration
    |> force_user_role()
  end

  def user_attrs(nil), do: %{}
  def user_attrs(_), do: %{}

  @doc """
  Normalize user attributes for admin-initiated user creation.

  Similar to user_attrs/1 but allows role selection by administrators.
  Should only be called from admin-protected endpoints.
  """
  def admin_user_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs =
      for {k, v} <- attrs, into: %{} do
        {to_string(k), v}
      end

    string_attrs
    |> Map.take(["email", "full_name", "role", "password", "password_confirmation"])
    |> normalize_email()
    |> normalize_full_name()
    |> normalize_role()
    |> add_defaults()
  end

  def admin_user_attrs(nil), do: %{}
  def admin_user_attrs(_), do: %{}

  @doc """
  Normalize user attributes for user updates.

  Only includes fields that can be updated and adds timestamp.
  """
  def user_update_attrs(attrs) when is_map(attrs) do
    # Convert atom keys to string keys for consistency
    string_attrs =
      for {k, v} <- attrs, into: %{} do
        {to_string(k), v}
      end

    string_attrs
    |> Map.take(["email", "full_name", "role", "status"])
    |> normalize_email()
    |> normalize_full_name()
    |> normalize_role()
    |> normalize_status()
    |> add_update_timestamp()
  end

  def user_update_attrs(nil), do: %{}
  def user_update_attrs(_), do: %{}

  @doc """
  Normalize password attributes for password changes.

  Ensures password fields are properly formatted.
  """
  def password_attrs(attrs) do
    attrs
    |> Map.take(["password", "password_confirmation", "current_password"])
    |> normalize_password_field("password")
    |> normalize_password_field("password_confirmation")
    |> normalize_password_field("current_password")
  end

  @doc """
  Normalize login attributes.

  Ensures email is properly formatted.
  """
  def login_attrs(attrs) do
    attrs
    |> Map.take(["email", "password"])
    |> normalize_email()
  end

  @doc """
  Normalize refresh token attributes.

  Ensures token is properly formatted.
  """
  def refresh_token_attrs(attrs) do
    attrs
    |> Map.take(["refresh_token"])
    |> normalize_refresh_token()
  end

  @doc """
  Normalize pagination parameters.

  Ensures page and page_size are valid integers with defaults.
  """
  def pagination_attrs(attrs) do
    %{
      "page" => normalize_page(attrs["page"]),
      "page_size" => normalize_page_size(attrs["page_size"])
    }
  end

  @doc """
  Normalize sort parameters.

  Parses sort string into list of {field, direction} tuples.
  """
  def sort_attrs(attrs) do
    case attrs["sort"] do
      nil ->
        []

      sort_string when is_binary(sort_string) ->
        sort_string
        |> String.split(",")
        |> Enum.map(&parse_sort_field/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @doc """
  Normalize filter parameters.

  Removes pagination and sort parameters, keeps only filter fields.
  """
  def filter_attrs(attrs) do
    attrs
    |> Map.drop(["page", "page_size", "sort"])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if is_binary(value) and String.trim(value) != "" do
        Map.put(acc, String.to_atom(key), value)
      else
        acc
      end
    end)
  end

  # Private helper functions

  defp normalize_email(attrs) do
    case attrs["email"] do
      email when is_binary(email) ->
        Map.put(attrs, "email", String.downcase(String.trim(email)))

      _ ->
        attrs
    end
  end

  defp normalize_full_name(attrs) do
    case attrs["full_name"] do
      name when is_binary(name) ->
        Map.put(attrs, "full_name", String.trim(name))

      _ ->
        attrs
    end
  end

  defp normalize_role(attrs) do
    case attrs["role"] do
      role when is_binary(role) ->
        normalized_role = String.downcase(String.trim(role))

        if normalized_role in ["user", "admin", "support"] do
          Map.put(attrs, "role", normalized_role)
        else
          # Remove invalid role
          Map.delete(attrs, "role")
        end

      _ ->
        attrs
    end
  end

  defp normalize_status(attrs) do
    case attrs["status"] do
      status when is_binary(status) ->
        normalized_status = String.upcase(String.trim(status))

        if normalized_status in ["ACTIVE", "SUSPENDED", "DELETED"] do
          Map.put(attrs, "status", normalized_status)
        else
          # Remove invalid status
          Map.delete(attrs, "status")
        end

      _ ->
        attrs
    end
  end

  defp normalize_password_field(attrs, field) do
    case attrs[field] do
      password when is_binary(password) ->
        Map.put(attrs, field, String.trim(password))

      _ ->
        attrs
    end
  end

  defp normalize_refresh_token(attrs) do
    case attrs["refresh_token"] do
      token when is_binary(token) ->
        Map.put(attrs, "refresh_token", String.trim(token))

      _ ->
        attrs
    end
  end

  defp normalize_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page_num, ""} when page_num >= 1 -> page_num
      _ -> 1
    end
  end

  defp normalize_page(_), do: 1

  defp normalize_page_size(page_size) when is_binary(page_size) do
    case Integer.parse(page_size) do
      {size, ""} when size >= 1 and size <= 100 -> size
      {size, ""} when size > 100 -> 100
      _ -> 20
    end
  end

  defp normalize_page_size(_), do: 20

  defp parse_sort_field(field_string) do
    case String.split(field_string, ":") do
      [field] ->
        {String.to_atom(String.trim(field)), :asc}

      [field, direction] when direction in ["asc", "desc"] ->
        {String.to_atom(String.trim(field)), String.to_atom(String.trim(direction))}

      _ ->
        nil
    end
  end

  defp add_defaults(attrs) do
    attrs
    |> Map.put_new("role", "user")
    |> Map.put_new("status", "ACTIVE")
  end

  defp add_update_timestamp(attrs) do
    Map.put(attrs, "updated_at", DateTime.utc_now())
  end

  defp force_user_role(attrs) do
    # SECURITY: Always force role to "user" for public registration
    # Admins must use admin_user_attrs/1 to create users with other roles
    Map.put(attrs, "role", "user")
  end
end

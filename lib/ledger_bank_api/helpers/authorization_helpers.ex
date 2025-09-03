defmodule LedgerBankApi.Helpers.AuthorizationHelpers do
  @moduledoc """
  Enhanced macros and helpers for role-based authorization in business logic.
  Provides comprehensive authorization checks and user permission validation.
  Usage:
    require_role!(user, "admin")
    require_permission!(user, :manage_payments)
    require_ownership!(user, resource)
  Raises a standardized forbidden error if the user does not have the required permissions.
  """

  defmacro require_role!(user, role) do
    quote do
      unless LedgerBankApi.Users.User.has_role?(unquote(user), unquote(role)) do
        raise %RuntimeError{message: "Insufficient permissions"}
      end
    end
  end

  defmacro require_any_role!(user, roles) do
    quote do
      unless Enum.any?(unquote(roles), fn role ->
        LedgerBankApi.Users.User.has_role?(unquote(user), role)
      end) do
        raise %RuntimeError{message: "Insufficient permissions"}
      end
    end
  end

  defmacro require_all_roles!(user, roles) do
    quote do
      unless Enum.all?(unquote(roles), fn role ->
        LedgerBankApi.Users.User.has_role?(unquote(user), role)
      end) do
        raise %RuntimeError{message: "Insufficient permissions"}
      end
    end
  end

  defmacro require_ownership!(user, resource) do
    quote do
      unless LedgerBankApi.Helpers.AuthorizationHelpers.owns_resource?(unquote(user), unquote(resource)) do
        raise %RuntimeError{message: "Access forbidden"}
      end
    end
  end

  defmacro validate_ownership(user, resource) do
    quote do
      if LedgerBankApi.Helpers.AuthorizationHelpers.owns_resource?(unquote(user), unquote(resource)) do
        {:ok, unquote(resource)}
      else
        {:error, :forbidden}
      end
    end
  end

  defmacro require_permission!(user, permission) do
    quote do
      unless LedgerBankApi.Helpers.AuthorizationHelpers.has_permission?(unquote(user), unquote(permission)) do
        raise %RuntimeError{message: "Insufficient permissions"}
      end
    end
  end

  @doc """
  Checks if a user owns a resource.
  """
  def owns_resource?(user, resource) do
    case resource do
      %{user_id: user_id} when user_id == user.id -> true
      %{user_bank_login: %{user_id: user_id}} when user_id == user.id -> true
      %{user_bank_account: %{user_bank_login: %{user_id: user_id}}} when user_id == user.id -> true
      %{account_id: account_id} -> owns_account?(user, account_id)
      %{user_bank_account_id: account_id} -> owns_account?(user, account_id)
      _ -> false
    end
  end

  @doc """
  Checks if a user owns a specific account by ID.
  """
  def owns_account?(user, account_id) do
    case LedgerBankApi.Banking.UserBankAccounts.get_with_preloads!(account_id, [:user_bank_login]) do
      %{user_bank_login: %{user_id: user_id}} when user_id == user.id -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Checks if a user owns a specific bank login by ID.
  """
  def owns_login?(user, login_id) do
    case LedgerBankApi.Banking.UserBankLogins.get_user_bank_login_with_preloads!(login_id, []) do
      %{user_id: user_id} when user_id == user.id -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Checks if a user has a specific permission.
  """
  def has_permission?(user, permission) do
    case permission do
      :manage_payments -> LedgerBankApi.Users.User.has_role?(user, "admin")
      :view_accounts -> true # All authenticated users can view their accounts
      :manage_accounts -> LedgerBankApi.Users.User.has_role?(user, "admin")
      :manage_users -> LedgerBankApi.Users.User.has_role?(user, "admin")
      :view_transactions -> true # All authenticated users can view their transactions
      :manage_transactions -> LedgerBankApi.Users.User.has_role?(user, "admin")
      :system_admin -> LedgerBankApi.Users.User.has_role?(user, "admin")
      _ -> false
    end
  end

  @doc """
  Checks if a user can access a specific resource.
  """
  def can_access?(user, resource, action) do
    cond do
      # Admin can do everything
      LedgerBankApi.Users.User.has_role?(user, "admin") -> true

      # User owns the resource
      owns_resource?(user, resource) ->
        case action do
          :read -> true
          :update -> true
          :delete -> true
          _ -> false
        end

      # Default deny
      true -> false
    end
  end

  @doc """
  Validates user access to a resource and returns {:ok, resource} or {:error, reason}.
  """
  def validate_access(user, resource, action) do
    if can_access?(user, resource, action) do
      {:ok, resource}
    else
      {:error, :forbidden}
    end
  end
end

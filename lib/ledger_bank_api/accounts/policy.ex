defmodule LedgerBankApi.Accounts.Policy do
  @moduledoc """
  Pure permission logic for user operations.

  This module contains all business rules for determining what actions
  users can perform. All functions are pure (no side effects) and
  easily testable.

  ## Usage

      # Check if user can update another user
      Policy.can_update_user?(current_user, target_user, attrs)

      # Check if user can change their own password
      Policy.can_change_password?(user, attrs)

      # Check if user can access user list
      Policy.can_list_users?(user)
  """

  @doc """
  Check if a user can update another user.

  ## Rules:
  - Admins can update any user
  - Users can update themselves (with restrictions)
  - Support users can update users (with restrictions)
  """
  def can_update_user?(actor, target_user, attrs) do
    cond do
      actor.role == "admin" ->
        true

      actor.id == target_user.id ->
        can_update_self?(attrs)

      actor.role == "support" ->
        can_support_update_user?(attrs)

      true ->
        false
    end
  end

  @doc """
  Check if a user can change their password.

  ## Rules:
  - User must provide current password
  - New password must meet requirements
  - New password must be different from current
  """
  def can_change_password?(_user, attrs) do
    current_password = attrs[:current_password] || attrs["current_password"]
    new_password = attrs[:password] || attrs["password"] || attrs[:new_password] || attrs["new_password"]

    cond do
      is_nil(current_password) ->
        false

      is_nil(new_password) ->
        false

      current_password == new_password ->
        false

      true ->
        true
    end
  end

  @doc """
  Check if a user can list other users.

  ## Rules:
  - Only admins and support users can list users
  """
  def can_list_users?(user) do
    user.role in ["admin", "support"]
  end

  @doc """
  Check if a user can view another user's details.

  ## Rules:
  - Admins can view any user
  - Users can view themselves
  - Support users can view any user
  """
  def can_view_user?(actor, target_user) do
    cond do
      actor.role == "admin" -> true
      actor.role == "support" -> true
      actor.id == target_user.id -> true
      true -> false
    end
  end

  @doc """
  Check if a user can delete another user.

  ## Rules:
  - Only admins can delete users
  - Users cannot delete themselves
  """
  def can_delete_user?(actor, target_user) do
    cond do
      actor.role != "admin" -> false
      actor.id == target_user.id -> false
      true -> true
    end
  end

  @doc """
  Check if a user can create other users.

  ## Rules:
  - Only admins can create users with admin role
  - Anyone can create regular users (registration)
  """
  def can_create_user?(actor, attrs) do
    role = attrs[:role] || attrs["role"] || "user"

    cond do
      role == "admin" and actor.role != "admin" -> false
      true -> true
    end
  end

  @doc """
  Check if a user can access user statistics.

  ## Rules:
  - Only admins can access statistics
  """
  def can_access_user_stats?(user) do
    user.role == "admin"
  end

  # Private helper functions

  @doc false
  def can_update_self?(attrs) do
    # Users can only update their own name, email, and password
    # Cannot change role, status, or other sensitive fields
    allowed_fields = ["full_name", "email", "password", "password_confirmation"]
    restricted_fields = ["role", "status", "active", "verified", "suspended", "deleted"]

    attrs_keys = Map.keys(attrs) |> Enum.map(&to_string/1)

    has_restricted_fields = Enum.any?(attrs_keys, &(&1 in restricted_fields))
    has_allowed_fields = Enum.any?(attrs_keys, &(&1 in allowed_fields))

    not has_restricted_fields and has_allowed_fields
  end

  @doc false
  def can_support_update_user?(attrs) do
    # Support users can update user details but not roles or status
    restricted_fields = ["role", "status", "active", "verified", "suspended", "deleted"]

    attrs_keys = Map.keys(attrs) |> Enum.map(&to_string/1)

    not Enum.any?(attrs_keys, &(&1 in restricted_fields))
  end
end

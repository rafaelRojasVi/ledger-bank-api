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

    new_password =
      attrs[:password] || attrs["password"] || attrs[:new_password] || attrs["new_password"]

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

  # ============================================================================
  # POLICY COMBINATORS
  # ============================================================================
  # These functions allow for complex authorization composition using
  # logical operators (AND, OR, NOT) and role-based policies.

  @doc """
  Policy combinator for AND logic.

  All policies must return true for the result to be true.

  ## Examples

      # User must be admin AND target must not be themselves
      Policy.all([
        fn -> Policy.is_admin?(user) end,
        fn -> user.id != target_user.id end
      ])
  """
  def all(policies) when is_list(policies) do
    Enum.all?(policies, fn policy ->
      case policy do
        fun when is_function(fun, 0) -> fun.()
        result when is_boolean(result) -> result
        _ -> false
      end
    end)
  end

  @doc """
  Policy combinator for OR logic.

  At least one policy must return true for the result to be true.

  ## Examples

      # User must be admin OR support OR viewing themselves
      Policy.any([
        fn -> Policy.is_admin?(user) end,
        fn -> Policy.is_support?(user) end,
        fn -> user.id == target_user.id end
      ])
  """
  def any(policies) when is_list(policies) do
    Enum.any?(policies, fn policy ->
      case policy do
        fun when is_function(fun, 0) -> fun.()
        result when is_boolean(result) -> result
        _ -> false
      end
    end)
  end

  @doc """
  Policy combinator for NOT logic.

  Inverts the result of a policy.

  ## Examples

      # User must NOT be the target user
      Policy.negate(fn -> user.id == target_user.id end)
  """
  def negate(policy) do
    case policy do
      fun when is_function(fun, 0) -> not fun.()
      result when is_boolean(result) -> not result
      _ -> true
    end
  end

  @doc """
  Role-based policy checker.

  ## Examples

      # User must have admin role
      Policy.has_role?(user, "admin")

      # User must have any of the specified roles
      Policy.has_any_role?(user, ["admin", "support"])
  """
  def has_role?(user, role) do
    user.role == role
  end

  @doc """
  Check if user has any of the specified roles.
  """
  def has_any_role?(user, roles) when is_list(roles) do
    user.role in roles
  end

  @doc """
  Check if user is an admin.
  """
  def is_admin?(user) do
    has_role?(user, "admin")
  end

  @doc """
  Check if user is support staff.
  """
  def is_support?(user) do
    has_role?(user, "support")
  end

  @doc """
  Check if user is a regular user.
  """
  def is_user?(user) do
    has_role?(user, "user")
  end

  @doc """
  Check if user is acting on themselves.
  """
  def is_self_action?(actor, target) do
    actor.id == target.id
  end

  @doc """
  Check if user is acting on a different user.
  """
  def is_other_user_action?(actor, target) do
    actor.id != target.id
  end

  @doc """
  Field-based policy checker.

  ## Examples

      # Check if attributes contain only allowed fields
      Policy.has_only_allowed_fields?(attrs, ["name", "email"])

      # Check if attributes contain any restricted fields
      Policy.has_restricted_fields?(attrs, ["role", "status"])
  """
  def has_only_allowed_fields?(attrs, allowed_fields) do
    attrs_keys = Map.keys(attrs) |> Enum.map(&to_string/1)
    Enum.all?(attrs_keys, &(&1 in allowed_fields))
  end

  @doc """
  Check if attributes contain any restricted fields.
  """
  def has_restricted_fields?(attrs, restricted_fields) do
    attrs_keys = Map.keys(attrs) |> Enum.map(&to_string/1)
    Enum.any?(attrs_keys, &(&1 in restricted_fields))
  end

  @doc """
  Complex policy composition example.

  This demonstrates how to use combinators for complex authorization logic.
  """
  def can_perform_sensitive_operation?(actor, target, attrs) do
    # Complex policy: (admin OR (support AND not_self)) AND no_restricted_fields
    all([
      # Either admin OR (support AND not acting on themselves)
      fn ->
        any([
          fn -> is_admin?(actor) end,
          fn ->
            all([fn -> is_support?(actor) end, fn -> is_other_user_action?(actor, target) end])
          end
        ])
      end,
      # No restricted fields in attributes
      fn ->
        negate(
          has_restricted_fields?(attrs, [
            "role",
            "status",
            "active",
            "verified",
            "suspended",
            "deleted"
          ])
        )
      end
    ])
  end
end

defmodule LedgerBankApi.Accounts.PolicyTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Accounts.Policy

  describe "can_update_user?/3" do
    test "admin can update any user" do
      admin = %{id: "admin-1", role: "admin"}
      user = %{id: "user-1", role: "user"}
      attrs = %{"role" => "support"}

      assert Policy.can_update_user?(admin, user, attrs) == true
    end

    test "user can update themselves with allowed fields" do
      user = %{id: "user-1", role: "user"}
      attrs = %{"full_name" => "New Name", "email" => "new@example.com"}

      assert Policy.can_update_user?(user, user, attrs) == true
    end

    test "user cannot update themselves with restricted fields" do
      user = %{id: "user-1", role: "user"}
      attrs = %{"role" => "admin", "status" => "SUSPENDED"}

      assert Policy.can_update_user?(user, user, attrs) == false
    end

    test "support user can update users but not roles/status" do
      support = %{id: "support-1", role: "support"}
      user = %{id: "user-1", role: "user"}
      attrs = %{"full_name" => "New Name"}

      assert Policy.can_update_user?(support, user, attrs) == true
    end

    test "support user cannot update roles or status" do
      support = %{id: "support-1", role: "support"}
      user = %{id: "user-1", role: "user"}
      attrs = %{"role" => "admin"}

      assert Policy.can_update_user?(support, user, attrs) == false
    end

    test "regular user cannot update other users" do
      user1 = %{id: "user-1", role: "user"}
      user2 = %{id: "user-2", role: "user"}
      attrs = %{"full_name" => "New Name"}

      assert Policy.can_update_user?(user1, user2, attrs) == false
    end
  end

  describe "can_change_password?/2" do
    test "user can change password with valid attributes" do
      user = %{id: "user-1", role: "user"}

      attrs = %{
        current_password: "old_password",
        password: "new_password"
      }

      assert Policy.can_change_password?(user, attrs) == true
    end

    test "user cannot change password without current password" do
      user = %{id: "user-1", role: "user"}
      attrs = %{password: "new_password"}

      assert Policy.can_change_password?(user, attrs) == false
    end

    test "user cannot change password without new password" do
      user = %{id: "user-1", role: "user"}
      attrs = %{current_password: "old_password"}

      assert Policy.can_change_password?(user, attrs) == false
    end

    test "user cannot use same password as current" do
      user = %{id: "user-1", role: "user"}

      attrs = %{
        current_password: "same_password",
        password: "same_password"
      }

      assert Policy.can_change_password?(user, attrs) == false
    end

    test "works with string keys" do
      user = %{id: "user-1", role: "user"}

      attrs = %{
        "current_password" => "old_password",
        "new_password" => "new_password"
      }

      assert Policy.can_change_password?(user, attrs) == true
    end
  end

  describe "can_list_users?/1" do
    test "admin can list users" do
      admin = %{id: "admin-1", role: "admin"}
      assert Policy.can_list_users?(admin) == true
    end

    test "support user can list users" do
      support = %{id: "support-1", role: "support"}
      assert Policy.can_list_users?(support) == true
    end

    test "regular user cannot list users" do
      user = %{id: "user-1", role: "user"}
      assert Policy.can_list_users?(user) == false
    end
  end

  describe "can_view_user?/2" do
    test "admin can view any user" do
      admin = %{id: "admin-1", role: "admin"}
      user = %{id: "user-1", role: "user"}

      assert Policy.can_view_user?(admin, user) == true
    end

    test "support user can view any user" do
      support = %{id: "support-1", role: "support"}
      user = %{id: "user-1", role: "user"}

      assert Policy.can_view_user?(support, user) == true
    end

    test "user can view themselves" do
      user = %{id: "user-1", role: "user"}

      assert Policy.can_view_user?(user, user) == true
    end

    test "user cannot view other users" do
      user1 = %{id: "user-1", role: "user"}
      user2 = %{id: "user-2", role: "user"}

      assert Policy.can_view_user?(user1, user2) == false
    end
  end

  describe "can_delete_user?/2" do
    test "admin can delete other users" do
      admin = %{id: "admin-1", role: "admin"}
      user = %{id: "user-1", role: "user"}

      assert Policy.can_delete_user?(admin, user) == true
    end

    test "admin cannot delete themselves" do
      admin = %{id: "admin-1", role: "admin"}

      assert Policy.can_delete_user?(admin, admin) == false
    end

    test "non-admin cannot delete users" do
      user1 = %{id: "user-1", role: "user"}
      user2 = %{id: "user-2", role: "user"}

      assert Policy.can_delete_user?(user1, user2) == false
    end

    test "support user cannot delete users" do
      support = %{id: "support-1", role: "support"}
      user = %{id: "user-1", role: "user"}

      assert Policy.can_delete_user?(support, user) == false
    end
  end

  describe "can_create_user?/2" do
    test "admin can create users with any role" do
      admin = %{id: "admin-1", role: "admin"}
      attrs = %{role: "admin"}

      assert Policy.can_create_user?(admin, attrs) == true
    end

    test "non-admin can create regular users" do
      user = %{id: "user-1", role: "user"}
      attrs = %{role: "user"}

      assert Policy.can_create_user?(user, attrs) == true
    end

    test "non-admin cannot create admin users" do
      user = %{id: "user-1", role: "user"}
      attrs = %{role: "admin"}

      assert Policy.can_create_user?(user, attrs) == false
    end

    test "defaults to user role when not specified" do
      user = %{id: "user-1", role: "user"}
      attrs = %{}

      assert Policy.can_create_user?(user, attrs) == true
    end
  end

  describe "can_access_user_stats?/1" do
    test "admin can access user statistics" do
      admin = %{id: "admin-1", role: "admin"}
      assert Policy.can_access_user_stats?(admin) == true
    end

    test "non-admin cannot access user statistics" do
      user = %{id: "user-1", role: "user"}
      assert Policy.can_access_user_stats?(user) == false
    end

    test "support user cannot access user statistics" do
      support = %{id: "support-1", role: "support"}
      assert Policy.can_access_user_stats?(support) == false
    end
  end

  # ============================================================================
  # POLICY COMBINATOR TESTS
  # ============================================================================

  describe "Policy Combinators" do
    test "all/1 returns true when all policies are true" do
      policies = [
        fn -> true end,
        fn -> true end,
        fn -> true end
      ]

      assert Policy.all(policies) == true
    end

    test "all/1 returns false when any policy is false" do
      policies = [
        fn -> true end,
        fn -> false end,
        fn -> true end
      ]

      assert Policy.all(policies) == false
    end

    test "all/1 works with boolean values" do
      policies = [true, true, true]
      assert Policy.all(policies) == true

      policies = [true, false, true]
      assert Policy.all(policies) == false
    end

    test "any/1 returns true when any policy is true" do
      policies = [
        fn -> false end,
        fn -> true end,
        fn -> false end
      ]

      assert Policy.any(policies) == true
    end

    test "any/1 returns false when all policies are false" do
      policies = [
        fn -> false end,
        fn -> false end,
        fn -> false end
      ]

      assert Policy.any(policies) == false
    end

    test "any/1 works with boolean values" do
      policies = [false, true, false]
      assert Policy.any(policies) == true

      policies = [false, false, false]
      assert Policy.any(policies) == false
    end

    test "negate/1 inverts function results" do
      assert Policy.negate(fn -> true end) == false
      assert Policy.negate(fn -> false end) == true
    end

    test "negate/1 inverts boolean values" do
      assert Policy.negate(true) == false
      assert Policy.negate(false) == true
    end

    test "negate/1 handles invalid input gracefully" do
      assert Policy.negate(:invalid) == true
    end
  end

  describe "Role-based Policy Checkers" do
    test "has_role?/2 checks specific role" do
      admin = %{role: "admin"}
      user = %{role: "user"}

      assert Policy.has_role?(admin, "admin") == true
      assert Policy.has_role?(admin, "user") == false
      assert Policy.has_role?(user, "user") == true
      assert Policy.has_role?(user, "admin") == false
    end

    test "has_any_role?/2 checks multiple roles" do
      admin = %{role: "admin"}
      support = %{role: "support"}
      user = %{role: "user"}

      assert Policy.has_any_role?(admin, ["admin", "support"]) == true
      assert Policy.has_any_role?(support, ["admin", "support"]) == true
      assert Policy.has_any_role?(user, ["admin", "support"]) == false
      assert Policy.has_any_role?(user, ["user"]) == true
    end

    test "is_admin?/1 checks admin role" do
      admin = %{role: "admin"}
      user = %{role: "user"}

      assert Policy.is_admin?(admin) == true
      assert Policy.is_admin?(user) == false
    end

    test "is_support?/1 checks support role" do
      support = %{role: "support"}
      user = %{role: "user"}

      assert Policy.is_support?(support) == true
      assert Policy.is_support?(user) == false
    end

    test "is_user?/1 checks user role" do
      user = %{role: "user"}
      admin = %{role: "admin"}

      assert Policy.is_user?(user) == true
      assert Policy.is_user?(admin) == false
    end
  end

  describe "Action-based Policy Checkers" do
    test "is_self_action?/2 checks if acting on self" do
      user1 = %{id: "user-1"}
      user2 = %{id: "user-2"}

      assert Policy.is_self_action?(user1, user1) == true
      assert Policy.is_self_action?(user1, user2) == false
    end

    test "is_other_user_action?/2 checks if acting on other user" do
      user1 = %{id: "user-1"}
      user2 = %{id: "user-2"}

      assert Policy.is_other_user_action?(user1, user1) == false
      assert Policy.is_other_user_action?(user1, user2) == true
    end
  end

  describe "Field-based Policy Checkers" do
    test "has_only_allowed_fields?/2 checks field restrictions" do
      attrs = %{"name" => "John", "email" => "john@example.com"}
      allowed_fields = ["name", "email", "password"]

      assert Policy.has_only_allowed_fields?(attrs, allowed_fields) == true
    end

    test "has_only_allowed_fields?/2 rejects restricted fields" do
      attrs = %{"name" => "John", "role" => "admin"}
      allowed_fields = ["name", "email", "password"]

      assert Policy.has_only_allowed_fields?(attrs, allowed_fields) == false
    end

    test "has_restricted_fields?/2 detects restricted fields" do
      attrs = %{"name" => "John", "role" => "admin"}
      restricted_fields = ["role", "status"]

      assert Policy.has_restricted_fields?(attrs, restricted_fields) == true
    end

    test "has_restricted_fields?/2 allows non-restricted fields" do
      attrs = %{"name" => "John", "email" => "john@example.com"}
      restricted_fields = ["role", "status"]

      assert Policy.has_restricted_fields?(attrs, restricted_fields) == false
    end
  end

  describe "Complex Policy Composition" do
    test "can_perform_sensitive_operation?/3 allows admin to perform operation" do
      admin = %{id: "admin-1", role: "admin"}
      target = %{id: "user-1", role: "user"}
      attrs = %{"name" => "John"}

      assert Policy.can_perform_sensitive_operation?(admin, target, attrs) == true
    end

    test "can_perform_sensitive_operation?/3 allows support to perform operation on others" do
      support = %{id: "support-1", role: "support"}
      target = %{id: "user-1", role: "user"}
      attrs = %{"name" => "John"}

      assert Policy.can_perform_sensitive_operation?(support, target, attrs) == true
    end

    test "can_perform_sensitive_operation?/3 denies support performing operation on themselves" do
      support = %{id: "support-1", role: "support"}
      attrs = %{"name" => "John"}

      assert Policy.can_perform_sensitive_operation?(support, support, attrs) == false
    end

    test "can_perform_sensitive_operation?/3 denies regular users" do
      user = %{id: "user-1", role: "user"}
      target = %{id: "user-2", role: "user"}
      attrs = %{"name" => "John"}

      assert Policy.can_perform_sensitive_operation?(user, target, attrs) == false
    end

    test "can_perform_sensitive_operation?/3 denies operation with restricted fields" do
      admin = %{id: "admin-1", role: "admin"}
      target = %{id: "user-1", role: "user"}
      attrs = %{"name" => "John", "role" => "admin"}

      assert Policy.can_perform_sensitive_operation?(admin, target, attrs) == false
    end
  end
end

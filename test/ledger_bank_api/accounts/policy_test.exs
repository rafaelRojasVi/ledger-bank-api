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
end

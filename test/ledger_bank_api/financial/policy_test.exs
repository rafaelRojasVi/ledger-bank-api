defmodule LedgerBankApi.Financial.PolicyTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Financial.Policy

  describe "can_create_payment?/2" do
    test "allows authenticated users to create payments" do
      user = %{id: 1, role: "user"}
      attrs = %{user_bank_account_id: "123e4567-e89b-12d3-a456-426614174000"}

      assert Policy.can_create_payment?(user, attrs) == true
    end

    test "denies unauthenticated users" do
      attrs = %{user_bank_account_id: "123e4567-e89b-12d3-a456-426614174000"}

      assert Policy.can_create_payment?(nil, attrs) == false
    end

    test "denies when user_bank_account_id is missing" do
      user = %{id: 1, role: "user"}
      attrs = %{}

      assert Policy.can_create_payment?(user, attrs) == false
    end
  end

  describe "can_view_account?/2" do
    test "allows admins to view any account" do
      admin = %{id: 1, role: "admin"}
      account = %{user_id: 999}

      assert Policy.can_view_account?(admin, account) == true
    end

    test "allows support users to view any account" do
      support = %{id: 1, role: "support"}
      account = %{user_id: 999}

      assert Policy.can_view_account?(support, account) == true
    end

    test "allows users to view their own accounts" do
      user = %{id: 1, role: "user"}
      account = %{user_id: 1}

      assert Policy.can_view_account?(user, account) == true
    end

    test "denies users from viewing other users' accounts" do
      user = %{id: 1, role: "user"}
      account = %{user_id: 999}

      assert Policy.can_view_account?(user, account) == false
    end

    test "denies unauthenticated users" do
      account = %{user_id: 1}

      assert Policy.can_view_account?(nil, account) == false
    end
  end

  describe "can_view_payment?/2" do
    test "allows admins to view any payment" do
      admin = %{id: 1, role: "admin"}
      payment = %{user_id: 999}

      assert Policy.can_view_payment?(admin, payment) == true
    end

    test "allows support users to view any payment" do
      support = %{id: 1, role: "support"}
      payment = %{user_id: 999}

      assert Policy.can_view_payment?(support, payment) == true
    end

    test "allows users to view their own payments" do
      user = %{id: 1, role: "user"}
      payment = %{user_id: 1}

      assert Policy.can_view_payment?(user, payment) == true
    end

    test "denies users from viewing other users' payments" do
      user = %{id: 1, role: "user"}
      payment = %{user_id: 999}

      assert Policy.can_view_payment?(user, payment) == false
    end
  end

  describe "can_process_payment?/2" do
    test "allows system to process payments (nil user)" do
      payment = %{id: 1}

      assert Policy.can_process_payment?(nil, payment) == true
    end

    test "allows admins to process payments" do
      admin = %{id: 1, role: "admin"}
      payment = %{id: 1, user_id: 2, status: "PENDING"}

      assert Policy.can_process_payment?(admin, payment) == true
    end

    test "denies regular users from processing payments" do
      user = %{id: 1, role: "user"}
      payment = %{id: 1, user_id: 2, status: "PENDING"}

      assert Policy.can_process_payment?(user, payment) == false
    end

    test "denies support users from processing payments" do
      support = %{id: 1, role: "support"}
      payment = %{id: 1, user_id: 2, status: "PENDING"}

      assert Policy.can_process_payment?(support, payment) == false
    end
  end

  describe "can_sync_account?/2" do
    test "allows system to sync accounts (nil user)" do
      account = %{user_id: 1}

      assert Policy.can_sync_account?(nil, account) == true
    end

    test "allows admins to sync any account" do
      admin = %{id: 1, role: "admin"}
      account = %{user_id: 999}

      assert Policy.can_sync_account?(admin, account) == true
    end

    test "allows support users to sync any account" do
      support = %{id: 1, role: "support"}
      account = %{user_id: 999}

      assert Policy.can_sync_account?(support, account) == true
    end

    test "allows users to sync their own accounts" do
      user = %{id: 1, role: "user"}
      account = %{user_id: 1}

      assert Policy.can_sync_account?(user, account) == true
    end

    test "denies users from syncing other users' accounts" do
      user = %{id: 1, role: "user"}
      account = %{user_id: 999}

      assert Policy.can_sync_account?(user, account) == false
    end
  end

  describe "can_cancel_payment?/2" do
    test "allows users to cancel their own pending payments" do
      user = %{id: 1, role: "user"}
      payment = %{id: 1, user_id: 1, status: "PENDING"}

      assert Policy.can_cancel_payment?(user, payment) == true
    end

    test "allows admins to cancel any pending payment" do
      admin = %{id: 1, role: "admin"}
      payment = %{id: 1, user_id: 999, status: "PENDING"}

      assert Policy.can_cancel_payment?(admin, payment) == true
    end

    test "allows support users to cancel any pending payment" do
      support = %{id: 1, role: "support"}
      payment = %{id: 1, user_id: 999, status: "PENDING"}

      assert Policy.can_cancel_payment?(support, payment) == true
    end

    test "denies canceling completed payments" do
      user = %{id: 1, role: "user"}
      payment = %{id: 1, user_id: 1, status: "COMPLETED"}

      assert Policy.can_cancel_payment?(user, payment) == false
    end

    test "denies canceling failed payments" do
      user = %{id: 1, role: "user"}
      payment = %{id: 1, user_id: 1, status: "FAILED"}

      assert Policy.can_cancel_payment?(user, payment) == false
    end

    test "denies users from canceling other users' payments" do
      user = %{id: 1, role: "user"}
      payment = %{id: 1, user_id: 999, status: "PENDING"}

      assert Policy.can_cancel_payment?(user, payment) == false
    end
  end

  describe "can_access_financial_stats?/1" do
    test "allows admins to access financial statistics" do
      admin = %{id: 1, role: "admin"}

      assert Policy.can_access_financial_stats?(admin) == true
    end

    test "denies regular users from accessing financial statistics" do
      user = %{id: 1, role: "user"}

      assert Policy.can_access_financial_stats?(user) == false
    end

    test "denies support users from accessing financial statistics" do
      support = %{id: 1, role: "support"}

      assert Policy.can_access_financial_stats?(support) == false
    end
  end

  describe "can_list_payments?/2" do
    test "allows all authenticated users to list payments" do
      user = %{id: 1, role: "user"}

      assert Policy.can_list_payments?(user) == true
    end

    test "allows admins to list payments" do
      admin = %{id: 1, role: "admin"}

      assert Policy.can_list_payments?(admin) == true
    end

    test "allows support users to list payments" do
      support = %{id: 1, role: "support"}

      assert Policy.can_list_payments?(support) == true
    end

    test "denies unauthenticated users" do
      assert Policy.can_list_payments?(nil) == false
    end
  end

  describe "can_update_bank_account?/3" do
    test "allows admins to update any account" do
      admin = %{id: 1, role: "admin"}
      account = %{user_id: 999}
      attrs = %{account_name: "New Name"}

      assert Policy.can_update_bank_account?(admin, account, attrs) == true
    end

    test "allows support users to update any account" do
      support = %{id: 1, role: "support"}
      account = %{user_id: 999}
      attrs = %{account_name: "New Name"}

      assert Policy.can_update_bank_account?(support, account, attrs) == true
    end

    test "allows users to update their own accounts with allowed fields" do
      user = %{id: 1, role: "user"}
      account = %{user_id: 1}
      attrs = %{account_name: "New Name"}

      assert Policy.can_update_bank_account?(user, account, attrs) == true
    end

    test "denies users from updating restricted fields" do
      user = %{id: 1, role: "user"}
      account = %{user_id: 1}
      attrs = %{currency: "EUR"}

      assert Policy.can_update_bank_account?(user, account, attrs) == false
    end

    test "denies users from updating other users' accounts" do
      user = %{id: 1, role: "user"}
      account = %{user_id: 999}
      attrs = %{account_name: "New Name"}

      assert Policy.can_update_bank_account?(user, account, attrs) == false
    end
  end
end

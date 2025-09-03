defmodule LedgerBankApi.Helpers.AuthorizationHelpersTest do
  use LedgerBankApi.DataCase, async: true
  import LedgerBankApi.Helpers.AuthorizationHelpers
  import LedgerBankApi.BankingFixtures
  import LedgerBankApi.UsersFixtures
  alias LedgerBankApi.UsersFixtures
  alias LedgerBankApi.BankingFixtures

  test "require_ownership! allows owner" do
    user = UsersFixtures.user_fixture()
    login = BankingFixtures.login_fixture(user)
    account = BankingFixtures.account_fixture(login)

    # Should not raise for owner
    require_ownership!(user, account)
  end

  test "require_ownership! raises for non-owner" do
    owner = UsersFixtures.user_fixture()
    other_user = UsersFixtures.user_fixture()
    login = BankingFixtures.login_fixture(owner)
    account = BankingFixtures.account_fixture(login)

    assert_raise RuntimeError, "Access forbidden", fn ->
      require_ownership!(other_user, account)
    end
  end

  test "require_ownership! with custom error message" do
    owner = UsersFixtures.user_fixture()
    other_user = UsersFixtures.user_fixture()
    login = BankingFixtures.login_fixture(owner)
    account = BankingFixtures.account_fixture(login)

    assert_raise RuntimeError, "Custom access denied message", fn ->
      require_ownership!(other_user, account, "Custom access denied message")
    end
  end

  test "require_ownership! with nested ownership" do
    user = UsersFixtures.user_fixture()
    login = BankingFixtures.login_fixture(user)
    account = BankingFixtures.account_fixture(login)
    payment = BankingFixtures.payment_fixture(account)

    # Test ownership through nested relationship
    require_ownership!(user, payment, "user_bank_account.user_bank_login.user_id")
  end

  test "require_ownership! with invalid ownership path" do
    user = UsersFixtures.user_fixture()
    login = BankingFixtures.login_fixture(user)
    account = BankingFixtures.account_fixture(login)

    assert_raise RuntimeError, "Invalid ownership path", fn ->
      require_ownership!(user, account, "invalid.path")
    end
  end

  test "require_role! allows user with required role" do
    admin_user = UsersFixtures.admin_user_fixture()

    # Should not raise for admin
    require_role!(admin_user, "admin")
  end

  test "require_role! raises for user without required role" do
    regular_user = UsersFixtures.user_fixture()

    assert_raise RuntimeError, "Insufficient permissions", fn ->
      require_role!(regular_user, "admin")
    end
  end

  test "require_role! with custom error message" do
    regular_user = UsersFixtures.user_fixture()

    assert_raise RuntimeError, "Admin access required", fn ->
      require_role!(regular_user, "admin", "Admin access required")
    end
  end

  test "require_any_role! allows user with any required role" do
    admin_user = UsersFixtures.admin_user_fixture()

    # Should not raise for admin
    require_any_role!(admin_user, ["admin", "moderator"])
  end

  test "require_any_role! raises for user without any required role" do
    regular_user = UsersFixtures.user_fixture()

    assert_raise RuntimeError, "Insufficient permissions", fn ->
      require_any_role!(regular_user, ["admin", "moderator"])
    end
  end

  test "require_any_role! with empty roles list" do
    user = UsersFixtures.user_fixture()

    assert_raise RuntimeError, "No roles specified", fn ->
      require_any_role!(user, [])
    end
  end
end

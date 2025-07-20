defmodule LedgerBankApi.Users.ContextAuthTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Users.Context
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    {:ok, user} = Context.create_user(%{email: "a@b.com", full_name: "A", role: "user", password: "abc12345"})
    %{user: user}
  end

  test "login_user returns tokens for valid credentials", %{user: user} do
    assert {:ok, db_user, access, refresh} = Context.login_user(user.email, "abc12345")
    assert db_user.id == user.id
    assert is_binary(access)
    assert is_binary(refresh)
  end

  test "login_user fails for invalid credentials", %{user: user} do
    assert {:error, :invalid_credentials} = Context.login_user(user.email, "wrongpass")
  end

  test "refresh_tokens rotates and revokes old token", %{user: user} do
    assert {:ok, db_user, _access, refresh} = Context.login_user(user.email, "abc12345")
    assert {:ok, db_user2, new_access, new_refresh} = Context.refresh_tokens(refresh)
    assert db_user2.id == user.id
    refute refresh == new_refresh
    # Old refresh token should now be revoked
    assert {:error, :invalid_refresh_token} = Context.refresh_tokens(refresh)
  end

  test "revoking all tokens logs out all sessions", %{user: user} do
    # Simulate two sessions
    assert {:ok, db_user, _access1, refresh1} = Context.login_user(user.email, "abc12345")
    assert {:ok, db_user2, _access2, refresh2} = Context.login_user(user.email, "abc12345")
    # Revoke all tokens
    {count, _} = Context.revoke_all_refresh_tokens_for_user(user.id)
    assert count >= 1
    assert {:error, :invalid_refresh_token} = Context.refresh_tokens(refresh1)
    assert {:error, :invalid_refresh_token} = Context.refresh_tokens(refresh2)
  end
end

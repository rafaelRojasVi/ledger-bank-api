defmodule LedgerBankApi.Helpers.AuthorizationHelpersTest do
  use ExUnit.Case, async: true
  import LedgerBankApi.Helpers.AuthorizationHelpers
  alias LedgerBankApi.Users.User

  test "require_role! allows correct role" do
    user = %User{role: "admin"}
    assert :ok == (try do
      require_role!(user, "admin")
      :ok
    rescue
      _ -> :error
    end)
  end

  test "require_role! raises for wrong role" do
    user = %User{role: "user"}
    assert_raise RuntimeError, fn ->
      require_role!(user, "admin")
    end
  end

  test "require_role! allows user role for user actions" do
    user = %User{role: "user"}
    assert :ok == (try do
      require_role!(user, "user")
      :ok
    rescue
      _ -> :error
    end)
  end
end

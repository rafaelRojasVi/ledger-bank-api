defmodule LedgerBankApi.Users.UserTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Users.User

  test "password is hashed and validated" do
    changeset = User.changeset(%User{}, %{email: "a@b.com", full_name: "A", role: "user", password: "abc12345"})
    assert changeset.valid?
    user = Ecto.Changeset.apply_changes(changeset)
    assert user.password_hash
    assert User.has_role?(user, "user")
    refute User.has_role?(user, "admin")
  end

  test "password complexity is enforced" do
    changeset = User.changeset(%User{}, %{email: "a@b.com", full_name: "A", role: "user", password: "short"})
    refute changeset.valid?
    assert Enum.any?(changeset.errors, fn {field, _} -> field == :password end)
  end

  test "email format is validated" do
    changeset = User.changeset(%User{}, %{email: "invalid", full_name: "A", role: "user", password: "abc12345"})
    refute changeset.valid?
    assert {:email, {"has invalid format", _}} = Enum.find(changeset.errors, fn {k, _} -> k == :email end)
  end

  test "password length is validated" do
    changeset = User.changeset(%User{}, %{email: "a@b.com", full_name: "A", role: "user", password: "short"})
    refute changeset.valid?
    assert Enum.any?(changeset.errors, fn {field, _} -> field == :password end)
  end

  test "is_admin?/1 returns true for admin" do
    user = %User{role: "admin"}
    assert User.is_admin?(user)
  end
end

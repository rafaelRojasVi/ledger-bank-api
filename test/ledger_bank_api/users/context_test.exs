defmodule LedgerBankApi.Users.ContextTest do
  use LedgerBankApi.DataCase
  alias LedgerBankApi.Users.{Context, User}
  alias LedgerBankApi.UsersFixtures
  alias LedgerBankApi.Auth

  test "authenticates user with valid credentials" do
    user = UsersFixtures.user_with_password_fixture("ValidPass123!")

    assert {:ok, authenticated_user} = Context.authenticate_user(user.email, "ValidPass123!")
    assert authenticated_user.id == user.id
    assert authenticated_user.email == user.email
  end

  test "fails authentication with invalid password" do
    user = UsersFixtures.user_with_password_fixture("ValidPass123!")

    assert {:error, :invalid_credentials} = Context.authenticate_user(user.email, "WrongPassword")
  end

  test "fails authentication with non-existent email" do
    assert {:error, :invalid_credentials} = Context.authenticate_user("nonexistent@example.com", "AnyPassword")
  end

  test "creates user successfully" do
    attrs = %{
      email: "newuser@example.com",
      full_name: "New User",
      password: "ValidPass123!",
      password_confirmation: "ValidPass123!"
    }

    assert {:ok, user} = Context.create_user(attrs)
    assert user.email == "newuser@example.com"
    assert user.full_name == "New User"
    assert user.role == "user" # default role
  end

  test "fails to create user with invalid data" do
    attrs = %{
      email: "invalid-email",
      full_name: "",
      password: "short",
      password_confirmation: "different"
    }

    assert {:error, changeset} = Context.create_user(attrs)
    assert "has invalid format" in errors_on(changeset)[:email]
    assert "can't be blank" in errors_on(changeset)[:full_name]
    assert "should be at least 8 character(s)" in errors_on(changeset)[:password]
    assert "does not match confirmation" in errors_on(changeset)[:password_confirmation]
  end

  test "fails to create user with duplicate email" do
    existing_user = UsersFixtures.user_fixture()

    attrs = %{
      email: existing_user.email,
      full_name: "Another User",
      password: "ValidPass123!",
      password_confirmation: "ValidPass123!"
    }

    assert {:error, changeset} = Context.create_user(attrs)
    assert "has already been taken" in errors_on(changeset)[:email]
  end

  test "generates access and refresh tokens on successful login" do
    user = UsersFixtures.user_with_password_fixture("ValidPass123!")

    assert {:ok, %{access_token: access_token, refresh_token: refresh_token}} =
      Context.login_user(user.email, "ValidPass123!")

    # Verify tokens are valid
    assert {:ok, access_claims} = Auth.verify_token(access_token)
    assert {:ok, refresh_claims} = Auth.verify_token(refresh_token)

    assert access_claims["sub"] == user.id
    assert access_claims["type"] == "access"
    assert refresh_claims["sub"] == user.id
    assert refresh_claims["type"] == "refresh"
  end

  test "refreshes access token with valid refresh token" do
    user = UsersFixtures.user_fixture()
    {:ok, refresh_token} = Auth.generate_refresh_token(user)

    assert {:ok, %{access_token: new_access_token, refresh_token: new_refresh_token}} =
      Context.refresh_tokens(refresh_token)

    # Verify new tokens
    assert {:ok, access_claims} = Auth.verify_token(new_access_token)
    assert {:ok, refresh_claims} = Auth.verify_token(new_refresh_token)

    assert access_claims["sub"] == user.id
    assert access_claims["type"] == "access"
    assert refresh_claims["sub"] == user.id
    assert refresh_claims["type"] == "refresh"
  end

  test "fails to refresh with invalid refresh token" do
    assert {:error, :invalid_token} = Context.refresh_tokens("invalid_token")
    assert {:error, :invalid_token} = Context.refresh_tokens("")
    assert {:error, :invalid_token} = Context.refresh_tokens(nil)
  end

  test "fails to refresh with expired refresh token" do
    user = UsersFixtures.user_fixture()

    # Create expired refresh token
    expired_claims = %{
      "sub" => user.id,
      "type" => "refresh",
      "exp" => DateTime.utc_now() |> DateTime.add(-10, :second) |> DateTime.to_unix()
    }

    {:ok, expired_token} = Auth.sign_token(expired_claims)
    assert {:error, :token_expired} = Context.refresh_tokens(expired_token)
  end

  test "fails to refresh with access token instead of refresh token" do
    user = UsersFixtures.user_fixture()
    {:ok, access_token} = Auth.generate_access_token(user)

    assert {:error, :invalid_token_type} = Context.refresh_tokens(access_token)
  end

  test "updates user profile successfully" do
    user = UsersFixtures.user_fixture()

    update_attrs = %{
      full_name: "Updated Name",
      email: "updated@example.com"
    }

    assert {:ok, updated_user} = Context.update_user(user, update_attrs)
    assert updated_user.full_name == "Updated Name"
    assert updated_user.email == "updated@example.com"
  end

  test "fails to update user with invalid data" do
    user = UsersFixtures.user_fixture()

    update_attrs = %{
      email: "invalid-email",
      full_name: ""
    }

    assert {:error, changeset} = Context.update_user(user, update_attrs)
    assert "has invalid format" in errors_on(changeset)[:email]
    assert "can't be blank" in errors_on(changeset)[:full_name]
  end

  test "fails to update user with duplicate email" do
    user1 = UsersFixtures.user_fixture()
    user2 = UsersFixtures.user_fixture()

    update_attrs = %{email: user2.email}

    assert {:error, changeset} = Context.update_user(user1, update_attrs)
    assert "has already been taken" in errors_on(changeset)[:email]
  end

  test "changes user password successfully" do
    user = UsersFixtures.user_with_password_fixture("OldPass123!")

    password_attrs = %{
      current_password: "OldPass123!",
      password: "NewPass456!",
      password_confirmation: "NewPass456!"
    }

    assert {:ok, updated_user} = Context.change_password(user, password_attrs)

    # Verify new password works
    assert {:ok, _} = Context.authenticate_user(user.email, "NewPass456!")
  end

  test "fails to change password with wrong current password" do
    user = UsersFixtures.user_with_password_fixture("OldPass123!")

    password_attrs = %{
      current_password: "WrongPass",
      password: "NewPass456!",
      password_confirmation: "NewPass456!"
    }

    assert {:error, :invalid_current_password} = Context.change_password(user, password_attrs)
  end

  test "fails to change password with mismatched confirmation" do
    user = UsersFixtures.user_with_password_fixture("OldPass123!")

    password_attrs = %{
      current_password: "OldPass123!",
      password: "NewPass456!",
      password_confirmation: "DifferentPass"
    }

    assert {:error, changeset} = Context.change_password(user, password_attrs)
    assert "does not match confirmation" in errors_on(changeset)[:password_confirmation]
  end

  test "deletes user successfully" do
    user = UsersFixtures.user_fixture()

    assert {:ok, deleted_user} = Context.delete_user(user)
    assert deleted_user.id == user.id

    # Verify user is deleted
    assert Repo.get(User, user.id) == nil
  end

  test "lists users with pagination" do
    # Create multiple users
    for i <- 1..5 do
      UsersFixtures.user_fixture(%{email: "user#{i}@example.com"})
    end

    assert {:ok, users, meta} = Context.list_users(%{"page" => 1, "per_page" => 3})
    assert length(users) == 3
    assert meta.total_count >= 5
    assert meta.current_page == 1
    assert meta.per_page == 3
  end

  test "filters users by role" do
    admin_user = UsersFixtures.admin_user_fixture()
    regular_user = UsersFixtures.user_fixture()

    assert {:ok, admin_users, _meta} = Context.list_users(%{"role" => "admin"})
    assert length(admin_users) == 1
    assert Enum.all?(admin_users, & &1.role == "admin")
  end

  test "searches users by name or email" do
    user1 = UsersFixtures.user_fixture(%{full_name: "John Doe", email: "john@example.com"})
    user2 = UsersFixtures.user_fixture(%{full_name: "Jane Smith", email: "jane@example.com"})

    assert {:ok, search_results, _meta} = Context.list_users(%{"search" => "John"})
    assert length(search_results) == 1
    assert Enum.at(search_results, 0).id == user1.id

    assert {:ok, email_results, _meta} = Context.list_users(%{"search" => "jane@example.com"})
    assert length(email_results) == 1
    assert Enum.at(email_results, 0).id == user2.id
  end
end

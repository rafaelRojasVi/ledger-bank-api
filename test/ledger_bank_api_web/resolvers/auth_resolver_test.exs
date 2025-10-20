defmodule LedgerBankApiWeb.Resolvers.AuthResolverTest do
  use LedgerBankApi.DataCase, async: true

  alias LedgerBankApiWeb.Resolvers.AuthResolver
  import LedgerBankApi.UsersFixtures

  describe "login/2" do
    test "logs in user with valid credentials" do
      user = user_fixture(%{password: "ValidPassword123!"})

      args = %{
        email: user.email,
        password: "ValidPassword123!"
      }
      context = %{}

      result = AuthResolver.login(args, context)
      assert {:ok, %{success: true, access_token: access_token, refresh_token: refresh_token, user: returned_user}} = result
      assert returned_user.id == user.id
      assert returned_user.email == user.email
      assert access_token != nil
      assert refresh_token != nil
    end

    test "returns error with invalid email" do
      args = %{
        email: "nonexistent@example.com",
        password: "password123"
      }
      context = %{}

      assert {:ok, %{success: false, access_token: nil, refresh_token: nil, user: nil, errors: errors}} = AuthResolver.login(args, context)
      assert length(errors) > 0
    end

    test "returns error with invalid password" do
      user = user_fixture(%{password: "ValidPassword123!"})

      args = %{
        email: user.email,
        password: "wrong_password"
      }
      context = %{}

      assert {:ok, %{success: false, access_token: nil, refresh_token: nil, user: nil, errors: errors}} = AuthResolver.login(args, context)
      assert length(errors) > 0
    end
  end

  describe "refresh/2" do
    test "refreshes token with valid refresh token" do
      user = user_fixture()

      # Create a valid refresh token
      {:ok, refresh_token} = LedgerBankApi.Accounts.AuthService.generate_refresh_token(user)

      args = %{
        refresh_token: refresh_token
      }
      context = %{}

      assert {:ok, %{success: true, access_token: access_token, refresh_token: new_refresh_token}} = AuthResolver.refresh(args, context)
      assert access_token != nil
      assert new_refresh_token != nil
    end

    test "returns error with invalid refresh token" do
      args = %{
        refresh_token: "invalid_refresh_token"
      }
      context = %{}

      assert {:ok, %{success: false, access_token: nil, refresh_token: nil, user: nil, errors: errors}} = AuthResolver.refresh(args, context)
      assert length(errors) > 0
    end
  end
end

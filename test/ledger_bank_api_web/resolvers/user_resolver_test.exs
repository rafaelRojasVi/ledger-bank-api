defmodule LedgerBankApiWeb.Resolvers.UserResolverTest do
  use LedgerBankApi.DataCase, async: true

  alias LedgerBankApiWeb.Resolvers.UserResolver
  import LedgerBankApi.UsersFixtures

  describe "find/2" do
    test "returns user when authenticated as owner" do
      user = user_fixture()

      args = %{id: user.id}
      context = %{context: %{current_user: user}}

      assert {:ok, found_user} = UserResolver.find(args, context)
      assert found_user.id == user.id
      assert found_user.email == user.email
    end

    test "returns user when authenticated as admin" do
      admin = user_fixture(%{role: "admin"})
      user = user_fixture()

      args = %{id: user.id}
      context = %{context: %{current_user: admin}}

      assert {:ok, found_user} = UserResolver.find(args, context)
      assert found_user.id == user.id
    end

    test "returns error when not authenticated" do
      user = user_fixture()

      args = %{id: user.id}
      context = %{}

      assert {:error, "Authentication required"} = UserResolver.find(args, context)
    end

    test "returns error when trying to access another user's data" do
      user1 = user_fixture()
      user2 = user_fixture()

      args = %{id: user2.id}
      context = %{context: %{current_user: user1}}

      assert {:error, "Access denied"} = UserResolver.find(args, context)
    end

    test "returns error when user not found" do
      user = user_fixture()

      args = %{id: "non-existent-id"}
      context = %{context: %{current_user: user}}

      assert {:error, "User not found"} = UserResolver.find(args, context)
    end
  end

  describe "list/2" do
    test "returns users when authenticated as admin" do
      admin = user_fixture(%{role: "admin"})
      _user1 = user_fixture()
      _user2 = user_fixture()

      args = %{limit: 10, offset: 0}
      context = %{context: %{current_user: admin}}

      assert {:ok, users} = UserResolver.list(args, context)
      assert length(users) >= 2
    end

    test "returns error when not authenticated" do
      args = %{limit: 10, offset: 0}
      context = %{}

      assert {:error, "Authentication required"} = UserResolver.list(args, context)
    end

    test "returns error when not admin" do
      user = user_fixture()

      args = %{limit: 10, offset: 0}
      context = %{context: %{current_user: user}}

      assert {:error, "Access denied"} = UserResolver.list(args, context)
    end

    test "handles pagination correctly" do
      admin = user_fixture(%{role: "admin"})

      # Create multiple users
      for i <- 1..15 do
        user_fixture(%{email: "user#{i}@example.com"})
      end

      # Test first page
      args = %{limit: 10, offset: 0}
      context = %{context: %{current_user: admin}}

      assert {:ok, users_page1} = UserResolver.list(args, context)
      assert length(users_page1) == 16

      # Test second page
      args = %{limit: 10, offset: 10}
      assert {:ok, users_page2} = UserResolver.list(args, context)
      assert length(users_page2) >= 5
    end
  end

  describe "create/2" do
    test "creates user with valid input" do
      input = %{
        email: "newuser@example.com",
        full_name: "New User",
        password: "password123",
        password_confirmation: "password123"
      }

      args = %{input: input}
      context = %{}

      assert {:ok, %{success: true, user: user}} = UserResolver.create(args, context)
      assert user.email == "newuser@example.com"
      assert user.full_name == "New User"
      assert user.role == "user"
      assert user.status == "ACTIVE"
    end

    test "returns validation errors with invalid email" do
      input = %{
        email: "invalid-email",
        full_name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      }

      args = %{input: input}
      context = %{}

      assert {:ok, %{success: false, user: nil, errors: errors}} =
               UserResolver.create(args, context)

      assert length(errors) > 0
    end

    test "returns validation errors with password mismatch" do
      input = %{
        email: "test@example.com",
        full_name: "Test User",
        password: "password123",
        password_confirmation: "different_password"
      }

      args = %{input: input}
      context = %{}

      assert {:ok, %{success: false, user: nil, errors: errors}} =
               UserResolver.create(args, context)

      assert length(errors) > 0
    end

    test "returns validation errors with missing required fields" do
      input = %{
        email: "test@example.com"
        # Missing full_name, password, password_confirmation
      }

      args = %{input: input}
      context = %{}

      assert {:ok, %{success: false, user: nil, errors: errors}} =
               UserResolver.create(args, context)

      assert length(errors) > 0
    end

    test "returns error when email already exists" do
      existing_user = user_fixture()

      input = %{
        email: existing_user.email,
        full_name: "Another User",
        password: "password123",
        password_confirmation: "password123"
      }

      args = %{input: input}
      context = %{}

      assert {:ok, %{success: false, user: nil, errors: errors}} =
               UserResolver.create(args, context)

      assert length(errors) > 0
    end
  end

  describe "update/2" do
    test "updates user when authenticated as owner" do
      user = user_fixture()

      input = %{
        full_name: "Updated Name",
        email: "updated@example.com"
      }

      args = %{id: user.id, input: input}
      context = %{context: %{current_user: user}}

      assert {:ok, %{success: true, user: updated_user}} = UserResolver.update(args, context)
      assert updated_user.full_name == "Updated Name"
      assert updated_user.email == "updated@example.com"
    end

    test "updates user when authenticated as admin" do
      admin = user_fixture(%{role: "admin"})
      user = user_fixture()

      input = %{
        full_name: "Admin Updated Name"
      }

      args = %{id: user.id, input: input}
      context = %{context: %{current_user: admin}}

      assert {:ok, %{success: true, user: updated_user}} = UserResolver.update(args, context)
      assert updated_user.full_name == "Admin Updated Name"
    end

    test "returns error when not authenticated" do
      user = user_fixture()

      input = %{full_name: "New Name"}
      args = %{id: user.id, input: input}
      context = %{}

      assert {:error, "Authentication required"} = UserResolver.update(args, context)
    end

    test "returns error when trying to update another user" do
      user1 = user_fixture()
      user2 = user_fixture()

      input = %{full_name: "Unauthorized Update"}
      args = %{id: user2.id, input: input}
      context = %{context: %{current_user: user1}}

      assert {:error, "Access denied"} = UserResolver.update(args, context)
    end

    test "returns error when user not found" do
      user = user_fixture()

      input = %{full_name: "New Name"}
      args = %{id: "non-existent-id", input: input}
      context = %{context: %{current_user: user}}

      assert {:error, "User not found"} = UserResolver.update(args, context)
    end
  end

  describe "me/2" do
    test "returns current user when authenticated" do
      user = user_fixture()

      context = %{context: %{current_user: user}}

      assert {:ok, returned_user} = UserResolver.me(%{}, context)
      assert returned_user.id == user.id
      assert returned_user.email == user.email
      assert returned_user.full_name == user.full_name
    end

    test "returns error when not authenticated" do
      context = %{}

      assert {:error, "Authentication required"} = UserResolver.me(%{}, context)
    end
  end
end

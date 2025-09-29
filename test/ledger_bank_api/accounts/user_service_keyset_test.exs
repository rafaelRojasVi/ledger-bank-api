defmodule LedgerBankApi.Accounts.UserServiceKeysetTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Accounts.UserService
  alias LedgerBankApi.UsersFixtures

  describe "list_users_keyset/1" do
    test "returns first page of users when no cursor provided" do
      # Create test users with different timestamps
      _user1 = UsersFixtures.user_fixture(%{email: "user1@example.com"})
      :timer.sleep(100) # Ensure different timestamps
      _user2 = UsersFixtures.user_fixture(%{email: "user2@example.com"})
      :timer.sleep(100)
      _user3 = UsersFixtures.user_fixture(%{email: "user3@example.com"})

      result = UserService.list_users_keyset(%{limit: 2})

      assert length(result.data) == 2
      assert result.has_more == true
      assert result.next_cursor != nil

      # Should be ordered by inserted_at desc
      [first_user, second_user] = result.data
      assert first_user.inserted_at >= second_user.inserted_at
    end

    test "returns next page when cursor provided" do
      # Create test users
      _user1 = UsersFixtures.user_fixture(%{email: "user1@example.com"})
      :timer.sleep(100)
      _user2 = UsersFixtures.user_fixture(%{email: "user2@example.com"})
      :timer.sleep(100)
      _user3 = UsersFixtures.user_fixture(%{email: "user3@example.com"})

      # Get first page
      first_result = UserService.list_users_keyset(%{limit: 2})

      # Get second page using cursor
      second_result = UserService.list_users_keyset(%{
        limit: 2,
        cursor: first_result.next_cursor
      })

      assert length(second_result.data) == 1
      assert second_result.has_more == false
      assert second_result.next_cursor == nil

      # Should be the oldest user
      [last_user] = second_result.data
      # Verify it's older than the users in the first page
      first_page_users = first_result.data
      assert Enum.all?(first_page_users, fn user ->
        last_user.inserted_at <= user.inserted_at
      end)
    end

    test "respects limit parameter" do
      # Create 5 users
      for i <- 1..5 do
        UsersFixtures.user_fixture(%{email: "user#{i}@example.com"})
        :timer.sleep(100)
      end

      result = UserService.list_users_keyset(%{limit: 3})

      assert length(result.data) == 3
      assert result.has_more == true
    end

    test "caps limit at 100" do
      # Create 5 users
      for i <- 1..5 do
        UsersFixtures.user_fixture(%{email: "user#{i}@example.com"})
        :timer.sleep(100)
      end

      result = UserService.list_users_keyset(%{limit: 200})

      assert length(result.data) == 5 # Only 5 users exist
      assert result.has_more == false
    end

    test "applies filters correctly" do
      # Create users with different roles
      _user1 = UsersFixtures.user_fixture(%{email: "user1@example.com", role: "user"})
      :timer.sleep(10)
      _admin1 = UsersFixtures.user_fixture(%{email: "admin1@example.com", role: "admin"})
      :timer.sleep(10)
      _user2 = UsersFixtures.user_fixture(%{email: "user2@example.com", role: "user"})

      result = UserService.list_users_keyset(%{
        limit: 10,
        filters: %{role: "user"}
      })

      assert length(result.data) == 2
      assert Enum.all?(result.data, &(&1.role == "user"))
    end

    test "returns empty result when no users match filters" do
      UsersFixtures.user_fixture(%{email: "user@example.com", role: "user"})

      result = UserService.list_users_keyset(%{
        limit: 10,
        filters: %{role: "admin"}
      })

      assert result.data == []
      assert result.has_more == false
      assert result.next_cursor == nil
    end

    test "handles invalid cursor gracefully" do
      UsersFixtures.user_fixture(%{email: "user@example.com"})

      # Invalid cursor should be treated as nil (first page)
      result = UserService.list_users_keyset(%{
        limit: 10,
        cursor: %{inserted_at: "invalid", id: "invalid"}
      })

      assert length(result.data) == 1
      assert result.has_more == false
    end

    test "returns has_more false when results less than limit" do
      UsersFixtures.user_fixture(%{email: "user@example.com"})

      result = UserService.list_users_keyset(%{limit: 10})

      assert length(result.data) == 1
      assert result.has_more == false
      assert result.next_cursor == nil
    end
  end
end

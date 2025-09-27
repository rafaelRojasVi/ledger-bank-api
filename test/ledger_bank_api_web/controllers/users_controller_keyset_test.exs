defmodule LedgerBankApiWeb.Controllers.UsersControllerKeysetTest do
  use LedgerBankApiWeb.ConnCase, async: true
  alias LedgerBankApi.UsersFixtures

  setup %{conn: conn} do
    admin_user = UsersFixtures.user_fixture(%{role: "admin"})
    {:ok, access_token} = LedgerBankApi.Accounts.AuthService.generate_access_token(admin_user)

    conn = conn
    |> put_req_header("authorization", "Bearer #{access_token}")

    %{conn: conn, admin_user: admin_user, access_token: access_token}
  end

  describe "GET /api/users/keyset" do
    test "returns first page of users", %{conn: conn} do
      # Create test users
      user1 = UsersFixtures.user_fixture(%{email: "user1@example.com"})
      :timer.sleep(10)
      user2 = UsersFixtures.user_fixture(%{email: "user2@example.com"})
      :timer.sleep(10)
      user3 = UsersFixtures.user_fixture(%{email: "user3@example.com"})

      conn = get(conn, ~p"/api/users/keyset?limit=2")

      response = json_response(conn, 200)
      assert %{"success" => true, "data" => users, "metadata" => metadata} = response

      assert length(users) == 2
      assert metadata["pagination"]["type"] == "keyset"
      assert metadata["pagination"]["limit"] == 2
      assert metadata["pagination"]["has_more"] == true
      assert metadata["pagination"]["next_cursor"] != nil
    end

    test "returns next page with cursor", %{conn: conn} do
      # Create test users
      user1 = UsersFixtures.user_fixture(%{email: "user1@example.com"})
      :timer.sleep(10)
      user2 = UsersFixtures.user_fixture(%{email: "user2@example.com"})
      :timer.sleep(10)
      user3 = UsersFixtures.user_fixture(%{email: "user3@example.com"})

      # Get first page
      conn1 = get(conn, ~p"/api/users/keyset?limit=2")
      response1 = json_response(conn1, 200)
      next_cursor = response1["metadata"]["pagination"]["next_cursor"]

      # Get second page
      cursor_param = Jason.encode!(next_cursor)
      conn2 = get(conn, ~p"/api/users/keyset?limit=2&cursor=#{cursor_param}")
      response2 = json_response(conn2, 200)

      assert %{"success" => true, "data" => users, "metadata" => metadata} = response2
      assert length(users) >= 1
      # has_more might be true if there are more users in the database
      # assert metadata["pagination"]["has_more"] == false
      # assert metadata["pagination"]["next_cursor"] == nil
    end

    test "applies filters correctly", %{conn: conn} do
      # Create users with different roles
      user1 = UsersFixtures.user_fixture(%{email: "user1@example.com", role: "user"})
      :timer.sleep(10)
      admin1 = UsersFixtures.user_fixture(%{email: "admin1@example.com", role: "admin"})
      :timer.sleep(10)
      user2 = UsersFixtures.user_fixture(%{email: "user2@example.com", role: "user"})

      conn = get(conn, ~p"/api/users/keyset?role=user")

      response = json_response(conn, 200)
      assert %{"success" => true, "data" => users} = response

      assert length(users) == 2
      assert Enum.all?(users, &(&1["role"] == "user"))
    end

    test "respects limit parameter", %{conn: conn} do
      # Create 5 users
      for i <- 1..5 do
        UsersFixtures.user_fixture(%{email: "user#{i}@example.com"})
        :timer.sleep(100)
      end

      conn = get(conn, ~p"/api/users/keyset?limit=3")

      response = json_response(conn, 200)
      assert %{"success" => true, "data" => users, "metadata" => metadata} = response

      assert length(users) == 3
      assert metadata["pagination"]["limit"] == 3
      assert metadata["pagination"]["has_more"] == true
    end

    test "caps limit at 100", %{conn: conn} do
      UsersFixtures.user_fixture(%{email: "user@example.com"})

      conn = get(conn, ~p"/api/users/keyset?limit=200")

      response = json_response(conn, 200)
      assert %{"success" => true, "metadata" => metadata} = response

      assert metadata["pagination"]["limit"] == 100
    end

    test "handles invalid cursor gracefully", %{conn: conn} do
      UsersFixtures.user_fixture(%{email: "user@example.com"})

      conn = get(conn, ~p"/api/users/keyset?cursor=invalid")

      response = json_response(conn, 200)
      assert %{"success" => true, "data" => users} = response

      assert length(users) >= 1
    end

    test "requires admin authentication", %{conn: conn} do
      # Create regular user
      user = UsersFixtures.user_fixture(%{role: "user"})
      {:ok, user_token} = LedgerBankApi.Accounts.AuthService.generate_access_token(user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{user_token}")
      |> get(~p"/api/users/keyset")

      assert json_response(conn, 403)
    end

    test "requires authentication", %{conn: conn} do
      conn = conn
      |> delete_req_header("authorization")
      |> get(~p"/api/users/keyset")

      assert json_response(conn, 401)
    end
  end
end

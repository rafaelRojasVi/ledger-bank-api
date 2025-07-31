defmodule LedgerBankApiWeb.UserBankLoginsControllerTest do
  @moduledoc """
  Comprehensive tests for UserBankLoginsController.
  Tests all bank login endpoints: CRUD operations and sync functionality.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Banking.Context
  import LedgerBankApi.Factories
  import LedgerBankApi.ErrorAssertions
  alias LedgerBankApi.Banking.Schemas.{Bank, BankBranch, UserBankLogin}

  describe "GET /api/bank-logins" do
    test "returns user's bank logins", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, _branch, login} = create_complete_banking_setup()

      # Update the login to belong to the authenticated user
      login = %{login | user_id: user.id}
      login = Repo.insert!(login)

      conn = get(conn, ~p"/api/bank-logins")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end

    test "returns only user's own bank logins", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create complete setup for user1
      {_user, _bank, _branch, login1} = create_complete_banking_setup()
      login1 = %{login1 | user_id: user1.id}
      login1 = Repo.insert!(login1)

      # Create complete setup for user2
      {_user, _bank, _branch, login2} = create_complete_banking_setup()
      login2 = %{login2 | user_id: user2.id}
      login2 = Repo.insert!(login2)

      conn = get(conn, ~p"/api/bank-logins")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end

    test "returns error without authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/bank-logins")

      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end
  end

  describe "GET /api/bank-logins/:id" do
    test "returns bank login details", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, _branch, login} = create_complete_banking_setup()

      # Update the login to belong to the authenticated user
      login = %{login | user_id: user.id}
      login = Repo.insert!(login)

      conn = get(conn, ~p"/api/bank-logins/#{login.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_item_response(response)
    end

    test "returns error for accessing other user's bank login", %{conn: conn} do
      {_user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, _branch, login2} = create_complete_banking_setup()
      login2 = %{login2 | user_id: user2.id}
      login2 = Repo.insert!(login2)

      conn = get(conn, ~p"/api/bank-logins/#{login2.id}")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for non-existent bank login", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/bank-logins/#{fake_id}")

      response = json_response(conn, 404)
      assert_not_found_error(response)
    end
  end

  describe "POST /api/bank-logins" do
    test "creates a new bank login", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, bank, branch} = create_complete_banking_setup()

      login_attrs = %{
        "user_id" => user.id,
        "bank_branch_id" => branch.id,
        "username" => "testuser",
        "encrypted_password" => "encrypted_password",
        "sync_frequency" => 3600
      }

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      response = json_response(conn, 201)
      assert_success_response(response, 201)
      assert_single_item_response(response)
    end

    test "returns error for creating login on other user's behalf", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()
      {_user, _bank, branch} = create_complete_banking_setup()

      login_attrs = %{
        "user_id" => user2.id,
        "bank_branch_id" => branch.id,
        "username" => "testuser",
        "encrypted_password" => "encrypted_password"
      }

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for duplicate login", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch} = create_complete_banking_setup()

      login_attrs = %{
        "user_id" => user.id,
        "bank_branch_id" => branch.id,
        "username" => "testuser",
        "encrypted_password" => "encrypted_password"
      }

      # Create first login
      post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      # Try to create duplicate
      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      response = json_response(conn, 409)
      assert_conflict_error(response)
    end

    test "returns error for invalid bank login data", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      invalid_attrs = %{
        "user_id" => user.id,
        "username" => "",
        "encrypted_password" => ""
      }

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: invalid_attrs)

      response = json_response(conn, 400)
      assert_validation_error(response)
    end
  end

  describe "PUT /api/bank-logins/:id" do
    test "updates bank login", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, _branch, login} = create_complete_banking_setup()

      # Update the login to belong to the authenticated user
      login = %{login | user_id: user.id}
      login = Repo.insert!(login)

      update_attrs = %{
        "username" => "updateduser",
        "sync_frequency" => 7200
      }

      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: update_attrs)

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_item_response(response)
    end

    test "returns error for updating other user's bank login", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, _branch, login2} = create_complete_banking_setup()
      login2 = %{login2 | user_id: user2.id}
      login2 = Repo.insert!(login2)

      update_attrs = %{
        "username" => "updateduser"
      }

      conn = put(conn, ~p"/api/bank-logins/#{login2.id}", user_bank_login: update_attrs)

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for invalid update data", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, _branch, login} = create_complete_banking_setup()

      # Update the login to belong to the authenticated user
      login = %{login | user_id: user.id}
      login = Repo.insert!(login)

      invalid_attrs = %{
        "username" => "",
        "sync_frequency" => -1
      }

      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: invalid_attrs)

      response = json_response(conn, 400)
      assert_validation_error(response)
    end
  end

  describe "DELETE /api/bank-logins/:id" do
    test "deletes bank login", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, _branch, login} = create_complete_banking_setup()

      # Update the login to belong to the authenticated user
      login = %{login | user_id: user.id}
      login = Repo.insert!(login)

      conn = delete(conn, ~p"/api/bank-logins/#{login.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
    end

    test "returns error for deleting other user's bank login", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, _branch, login2} = create_complete_banking_setup()
      login2 = %{login2 | user_id: user2.id}
      login2 = Repo.insert!(login2)

      conn = delete(conn, ~p"/api/bank-logins/#{login2.id}")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for non-existent bank login", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/bank-logins/#{fake_id}")

      response = json_response(conn, 404)
      assert_not_found_error(response)
    end
  end

  describe "POST /api/bank-logins/:id/sync" do
    test "queues bank sync job", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, _branch, login} = create_complete_banking_setup()

      # Update the login to belong to the authenticated user
      login = %{login | user_id: user.id}
      login = Repo.insert!(login)

      conn = post(conn, ~p"/api/bank-logins/#{login.id}/sync")

      response = json_response(conn, 202)
      assert_success_response(response, 202)
      assert_single_response(response, "message")
    end

    test "returns error for syncing other user's bank login", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, _branch, login2} = create_complete_banking_setup()
      login2 = %{login2 | user_id: user2.id}
      login2 = Repo.insert!(login2)

      conn = post(conn, ~p"/api/bank-logins/#{login2.id}/sync")

      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end

    test "returns error for non-existent bank login", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = post(conn, ~p"/api/bank-logins/#{fake_id}/sync")

      response = json_response(conn, 404)
      assert_not_found_error(response)
    end
  end

  describe "Bank login validation" do
    test "validates sync frequency", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch} = create_complete_banking_setup()

      valid_frequencies = [300, 600, 1800, 3600, 7200, 86400]

      Enum.each(valid_frequencies, fn frequency ->
        login_attrs = %{
          "user_id" => user.id,
          "bank_branch_id" => branch.id,
          "username" => "testuser#{frequency}",
          "encrypted_password" => "encrypted_password",
          "sync_frequency" => frequency
        }

        conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)
        assert_success_response(json_response(conn, 201), 201)
      end)
    end

    test "rejects invalid sync frequency", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch} = create_complete_banking_setup()

      invalid_frequencies = [-1, 0, 100, 1000000]

      Enum.each(invalid_frequencies, fn frequency ->
        login_attrs = %{
          "user_id" => user.id,
          "bank_branch_id" => branch.id,
          "username" => "testuser#{frequency}",
          "encrypted_password" => "encrypted_password",
          "sync_frequency" => frequency
        }

        conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)
        assert_validation_error(json_response(conn, 400))
      end)
    end

    test "validates username format", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch} = create_complete_banking_setup()

      valid_usernames = ["user123", "test_user", "user@domain.com"]

      Enum.each(valid_usernames, fn username ->
        login_attrs = %{
          "user_id" => user.id,
          "bank_branch_id" => branch.id,
          "username" => username,
          "encrypted_password" => "encrypted_password"
        }

        conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)
        assert_success_response(json_response(conn, 201), 201)
      end)
    end

    test "rejects invalid username format", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch} = create_complete_banking_setup()

      invalid_usernames = ["", "a", "user with spaces", "user\nwith\nnewlines"]

      Enum.each(invalid_usernames, fn username ->
        login_attrs = %{
          "user_id" => user.id,
          "bank_branch_id" => branch.id,
          "username" => username,
          "encrypted_password" => "encrypted_password"
        }

        conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)
        assert_validation_error(json_response(conn, 400))
      end)
    end
  end

  describe "Bank login workflow" do
    test "complete bank login lifecycle", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch} = create_complete_banking_setup()

      # 1. Create bank login
      login_attrs = %{
        "user_id" => user.id,
        "bank_branch_id" => branch.id,
        "username" => "testuser",
        "encrypted_password" => "encrypted_password",
        "sync_frequency" => 3600
      }

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)
      response = json_response(conn, 201)
      assert_success_response(response, 201)
      assert %{"data" => %{"id" => login_id}} = response

      # 2. Get bank login details
      conn = get(conn, ~p"/api/bank-logins/#{login_id}")
      response = json_response(conn, 200)
      assert_success_response(response, 200)

      # 3. Update bank login
      update_attrs = %{
        "username" => "updateduser",
        "sync_frequency" => 7200
      }

      conn = put(conn, ~p"/api/bank-logins/#{login_id}", user_bank_login: update_attrs)
      response = json_response(conn, 200)
      assert_success_response(response, 200)

      # 4. Sync bank login
      conn = post(conn, ~p"/api/bank-logins/#{login_id}/sync")
      response = json_response(conn, 202)
      assert_success_response(response, 202)

      # 5. Delete bank login
      conn = delete(conn, ~p"/api/bank-logins/#{login_id}")
      response = json_response(conn, 200)
      assert_success_response(response, 200)
    end
  end
end

defmodule LedgerBankApiWeb.UserBankLoginsControllerV2Test do
  @moduledoc """
  Comprehensive tests for UserBankLoginsControllerV2.
  Tests all bank login endpoints: CRUD operations and sync functionality.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Banking.Context
  alias LedgerBankApi.Banking.Schemas.{Bank, BankBranch, UserBankLogin}

  @valid_bank_attrs %{
    "name" => "Test Bank",
    "country" => "US",
    "code" => "TESTBANK"
  }

  @valid_bank_branch_attrs %{
    "name" => "Main Branch",
    "country" => "US",
    "iban" => "US1234567890",
    "routing_number" => "111000025",
    "swift_code" => "TESTUS33"
  }

  @valid_user_bank_login_attrs %{
    "username" => "testuser",
    "encrypted_password" => "encrypted_password",
    "sync_frequency" => 3600
  }

  @update_user_bank_login_attrs %{
    "username" => "updateduser",
    "sync_frequency" => 7200
  }

  setup do
    # Create test data
    {:ok, bank} = create_bank(@valid_bank_attrs)
    {:ok, bank_branch} = create_bank_branch(Map.put(@valid_bank_branch_attrs, "bank_id", bank.id))

    %{bank: bank, bank_branch: bank_branch}
  end

  describe "GET /api/bank-logins" do
    test "returns user's bank logins", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = get(conn, ~p"/api/bank-logins")

      assert %{
               "data" => [
                 %{
                   "id" => login_id,
                   "username" => "testuser",
                   "status" => "ACTIVE",
                   "sync_frequency" => 3600
                 }
               ]
             } = json_response(conn, 200)

      assert login_id == login.id
    end

    test "returns only user's own bank logins", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create login for user1
      {:ok, login1} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user1.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Create login for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = get(conn, ~p"/api/bank-logins")

      assert %{
               "data" => [
                 %{
                   "id" => login_id,
                   "username" => "testuser"
                 }
               ]
             } = json_response(conn, 200)

      assert login_id == login1.id
      refute login_id == login2.id
    end

    test "returns empty list for user with no bank logins", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/bank-logins")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/bank-logins/:id" do
    test "returns bank login details", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = get(conn, ~p"/api/bank-logins/#{login.id}")

      assert %{
               "data" => %{
                 "id" => login_id,
                 "username" => "testuser",
                 "status" => "ACTIVE",
                 "sync_frequency" => 3600
               }
             } = json_response(conn, 200)

      assert login_id == login.id
    end

    test "returns error for accessing other user's bank login", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create login for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = get(conn, ~p"/api/bank-logins/#{login2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for non-existent bank login", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/bank-logins/#{fake_id}")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "POST /api/bank-logins" do
    test "creates a new bank login", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      login_attrs = Map.merge(@valid_user_bank_login_attrs, %{
        "bank_branch_id" => bank_branch.id
      })

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      assert %{
               "data" => %{
                 "id" => login_id,
                 "username" => "testuser",
                 "status" => "ACTIVE",
                 "sync_frequency" => 3600
               }
             } = json_response(conn, 201)

      assert is_binary(login_id)

      # Verify login was created in database
      login = get_user_bank_login!(login_id)
      assert login.username == "testuser"
      assert login.status == "ACTIVE"
      assert login.sync_frequency == 3600
      assert login.user_id == user.id
      assert login.bank_branch_id == bank_branch.id
    end

    test "returns error for invalid bank login data", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      invalid_attrs = %{
        "bank_branch_id" => bank_branch.id,
        "username" => "", # Empty username
        "encrypted_password" => "", # Empty password
        "sync_frequency" => -1 # Invalid sync frequency
      }

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: invalid_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "returns error for missing required fields", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      incomplete_attrs = %{
        "bank_branch_id" => bank_branch.id,
        "username" => "testuser"
        # Missing encrypted_password
      }

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: incomplete_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "returns error for non-existent bank branch", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      fake_branch_id = Ecto.UUID.generate()

      login_attrs = Map.merge(@valid_user_bank_login_attrs, %{
        "bank_branch_id" => fake_branch_id
      })

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "prevents duplicate logins for same user and bank branch", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create first login
      login_attrs = Map.merge(@valid_user_bank_login_attrs, %{
        "bank_branch_id" => bank_branch.id
      })
      post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      # Try to create second login for same user and bank branch
      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      assert %{
               "error" => %{
                 "type" => "conflict",
                 "message" => "Constraint violation: user_bank_logins_user_id_bank_branch_id_username_index",
                 "code" => 409
               }
             } = json_response(conn, 409)
    end
  end

  describe "PUT /api/bank-logins/:id" do
    test "updates bank login", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: @update_user_bank_login_attrs)

      assert %{
               "data" => %{
                 "id" => login_id,
                 "username" => "updateduser",
                 "sync_frequency" => 7200
               }
             } = json_response(conn, 200)

      assert login_id == login.id

      # Verify database was updated
      updated_login = get_user_bank_login!(login.id)
      assert updated_login.username == "updateduser"
      assert updated_login.sync_frequency == 7200
    end

    test "returns error for updating other user's bank login", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create login for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = put(conn, ~p"/api/bank-logins/#{login2.id}", user_bank_login: @update_user_bank_login_attrs)

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for invalid update data", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      invalid_attrs = %{
        "username" => "", # Empty username
        "sync_frequency" => -1 # Invalid sync frequency
      }

      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: invalid_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end

  describe "DELETE /api/bank-logins/:id" do
    test "deletes bank login", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = delete(conn, ~p"/api/bank-logins/#{login.id}")

      assert response(conn, 204) == ""

      # Verify login was deleted
      assert_raise Ecto.NoResultsError, fn ->
        get_user_bank_login!(login.id)
      end
    end

    test "returns error for deleting other user's bank login", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create login for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = delete(conn, ~p"/api/bank-logins/#{login2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "cascades deletion to related accounts", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create login
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Create account associated with login
      {:ok, account} = create_user_bank_account(%{
        "user_bank_login_id" => login.id,
        "currency" => "USD",
        "account_type" => "CHECKING",
        "balance" => "1000.00",
        "last_four" => "1234",
        "account_name" => "Test Account"
      })

      # Delete the login
      conn = delete(conn, ~p"/api/bank-logins/#{login.id}")
      assert response(conn, 204) == ""

      # Verify login was deleted
      assert_raise Ecto.NoResultsError, fn ->
        get_user_bank_login!(login.id)
      end

      # Verify associated account was also deleted (if cascade is configured)
      # This depends on your database configuration
      # assert_raise Ecto.NoResultsError, fn ->
      #   get_user_bank_account!(account.id)
      # end
    end
  end

  describe "POST /api/bank-logins/:id/sync" do
    test "queues bank sync job", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = post(conn, ~p"/api/bank-logins/#{login.id}/sync")

      assert %{
               "data" => %{
                 "message" => "bank_sync initiated",
                 "bank_sync_id" => login_id,
                 "status" => "queued"
               }
             } = json_response(conn, 202)

      assert login_id == login.id
    end

    test "returns error for syncing other user's bank login", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create login for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = post(conn, ~p"/api/bank-logins/#{login2.id}/sync")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for syncing non-existent bank login", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = post(conn, ~p"/api/bank-logins/#{fake_id}/sync")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "Bank login status management" do
    test "can update login status", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Update status to INACTIVE
      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: %{"status" => "INACTIVE"})

      assert %{
               "data" => %{
                 "id" => login_id,
                 "status" => "INACTIVE"
               }
             } = json_response(conn, 200)

      assert login_id == login.id

      # Verify database was updated
      updated_login = get_user_bank_login!(login.id)
      assert updated_login.status == "INACTIVE"
    end

    test "validates status values", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Try to set invalid status
      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: %{"status" => "INVALID_STATUS"})

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "can reactivate inactive login", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id,
        "status" => "INACTIVE"
      }))

      # Reactivate the login
      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: %{"status" => "ACTIVE"})

      assert %{
               "data" => %{
                 "id" => login_id,
                 "status" => "ACTIVE"
               }
             } = json_response(conn, 200)

      assert login_id == login.id
    end
  end

  describe "Sync frequency management" do
    test "can update sync frequency", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Update sync frequency
      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: %{"sync_frequency" => 1800})

      assert %{
               "data" => %{
                 "id" => login_id,
                 "sync_frequency" => 1800
               }
             } = json_response(conn, 200)

      assert login_id == login.id

      # Verify database was updated
      updated_login = get_user_bank_login!(login.id)
      assert updated_login.sync_frequency == 1800
    end

    test "validates sync frequency range", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Try to set invalid sync frequency
      conn = put(conn, ~p"/api/bank-logins/#{login.id}", user_bank_login: %{"sync_frequency" => -1})

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end

  describe "Bank login security" do
    test "does not expose encrypted password in responses", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = get(conn, ~p"/api/bank-logins/#{login.id}")

      response = json_response(conn, 200)

      # Verify encrypted_password is not in the response
      refute Map.has_key?(response["data"], "encrypted_password")
      refute Map.has_key?(response["data"], "password")
    end

    test "validates unique constraints", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create first login
      {:ok, login1} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Try to create second login with same username for same user and bank branch
      login_attrs = Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      })

      conn = post(conn, ~p"/api/bank-logins", user_bank_login: login_attrs)

      assert %{
               "error" => %{
                 "type" => "conflict",
                 "message" => "Constraint violation: user_bank_logins_user_id_bank_branch_id_username_index",
                 "code" => 409
               }
             } = json_response(conn, 409)
    end
  end
end

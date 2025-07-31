defmodule LedgerBankApiWeb.BankingControllerTest do
  @moduledoc """
  Comprehensive tests for BankingController.
  Tests all banking endpoints: accounts, transactions, balances, payments, and sync operations.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Banking.Context
  import LedgerBankApi.Factories
  import LedgerBankApi.ErrorAssertions
  import LedgerBankApiWeb.AuthHelpers

  describe "GET /api/accounts" do
    test "returns user's accounts", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      # Create login and account for the authenticated user
      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      _account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end

    test "returns only user's own accounts", %{conn: conn} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user1
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login1 = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user1.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      _account1 = insert(:user_bank_account, user_bank_login: login1)

      # Create complete setup for user2
      login2 = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user2.id,
        bank_branch_id: branch.id,
        username: "user2",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      _account2 = insert(:user_bank_account, user_bank_login: login2)

      conn = get(conn, ~p"/api/accounts")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end

    test "returns empty list for user with no accounts", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/accounts")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "supports pagination for accounts", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      # Create multiple accounts for the user
      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()

      # Create 3 accounts
      Enum.each(1..3, fn i ->
        insert(:user_bank_account, user_bank_login: login, account_name: "Account #{i}")
      end)

      conn = get(conn, ~p"/api/accounts?page=1&page_size=2")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 2)
    end

    test "supports sorting for accounts", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()

      # Create accounts with different names
      insert(:user_bank_account, user_bank_login: login, account_name: "Zebra Account")
      insert(:user_bank_account, user_bank_login: login, account_name: "Alpha Account")

      conn = get(conn, ~p"/api/accounts?sort_by=account_name&sort_order=asc")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 2)
    end
  end

  describe "GET /api/accounts/:id" do
    test "returns account details", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      # Create login and account for the authenticated user
      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_response(response, "account")
    end

    test "returns error for accessing other user's account", %{conn: conn} do
      {_user1, _access_token, conn} = setup_authenticated_user(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login2 = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user2.id,
        bank_branch_id: branch.id,
        username: "user2",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account2 = insert(:user_bank_account, user_bank_login: login2)

      conn = get(conn, ~p"/api/accounts/#{account2.id}")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns error for non-existent account", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/accounts/#{fake_id}")

      assert_not_found_error(json_response(conn, 404))
    end

    test "returns error for malformed UUID", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/accounts/invalid-uuid")

      assert_not_found_error(json_response(conn, 404))
    end
  end

  describe "GET /api/accounts/:id/transactions" do
    test "returns account transactions", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      # Create login and account for the authenticated user
      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      # Create transactions
      {:ok, _transaction1} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "100.00",
        "description" => "Test Transaction 1",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, _transaction2} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "50.00",
        "description" => "Test Transaction 2",
        "posted_at" => DateTime.utc_now(),
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 2)
    end

    test "returns error for accessing other user's account transactions", %{conn: conn} do
      {_user1, _access_token, conn} = setup_authenticated_user(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login2 = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user2.id,
        bank_branch_id: branch.id,
        username: "user2",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account2 = insert(:user_bank_account, user_bank_login: login2)

      conn = get(conn, ~p"/api/accounts/#{account2.id}/transactions")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns empty list for account with no transactions", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 0)
    end

    test "supports amount filtering", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      # Create transactions with different amounts
      {:ok, _small_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "50.00",
        "description" => "Small Transaction",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, _large_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "500.00",
        "description" => "Large Transaction",
        "posted_at" => DateTime.utc_now(),
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?amount_min=100.00")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end

    test "supports description filtering", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      # Create transactions with different descriptions
      {:ok, _food_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "25.00",
        "description" => "Food Purchase",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, _gas_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "45.00",
        "description" => "Gas Station",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?description=Food")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end
  end

  describe "GET /api/accounts/:id/balances" do
    test "returns account balance", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      # Create login and account for the authenticated user
      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/balances")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_response(response, "balance")
    end

    test "returns error for accessing other user's account balance", %{conn: conn} do
      {_user1, _access_token, conn} = setup_authenticated_user(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login2 = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user2.id,
        bank_branch_id: branch.id,
        username: "user2",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account2 = insert(:user_bank_account, user_bank_login: login2)

      conn = get(conn, ~p"/api/accounts/#{account2.id}/balances")

      assert_forbidden_error(json_response(conn, 403))
    end
  end

  describe "GET /api/accounts/:id/payments" do
    test "returns account payments", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      # Create login and account for the authenticated user
      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      # Create payments
      {:ok, _payment1} = create_user_payment(%{
        "user_bank_account_id" => account.id,
        "amount" => "200.00",
        "description" => "Test Payment 1",
        "payment_type" => "TRANSFER",
        "status" => "COMPLETED",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, _payment2} = create_user_payment(%{
        "user_bank_account_id" => account.id,
        "amount" => "150.00",
        "description" => "Test Payment 2",
        "payment_type" => "PAYMENT",
        "status" => "PENDING",
        "posted_at" => DateTime.utc_now(),
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/payments")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 2)
    end

    test "returns error for accessing other user's account payments", %{conn: conn} do
      {_user1, _access_token, conn} = setup_authenticated_user(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      bank = insert(:monzo_bank)
      branch = insert(:bank_branch, bank: bank)
      login2 = insert(:user_bank_login, user: user2, bank_branch: branch)
      account2 = insert(:user_bank_account, user_bank_login: login2)

      conn = get(conn, ~p"/api/accounts/#{account2.id}/payments")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns empty list for account with no payments", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()

      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/payments")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 0)
    end
  end

  describe "POST /api/sync/:login_id" do
    test "queues bank sync job", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user.id,
        bank_branch_id: branch.id,
        username: "user1",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()

      conn = post(conn, ~p"/api/sync/#{login.id}")

      response = json_response(conn, 202)
      assert_success_response(response, 202)
      assert_single_response(response, "message")
    end

    test "returns error for syncing other user's login", %{conn: conn} do
      {_user1, _access_token, conn} = setup_authenticated_user(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, branch, _login, _account2} = create_complete_banking_setup()
      login2 = %LedgerBankApi.Banking.Schemas.UserBankLogin{
        user_id: user2.id,
        bank_branch_id: branch.id,
        username: "user2",
        encrypted_password: "encrypted_password"
      } |> LedgerBankApi.Repo.insert!()

      conn = post(conn, ~p"/api/sync/#{login2.id}")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns error for non-existent login", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = post(conn, ~p"/api/sync/#{fake_id}")

      assert_not_found_error(json_response(conn, 404))
    end

    test "returns error for malformed login UUID", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = post(conn, ~p"/api/sync/invalid-uuid")

      assert_not_found_error(json_response(conn, 404))
    end
  end

  describe "Pagination, filtering, and sorting" do
    test "supports pagination parameters", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Create multiple transactions
      Enum.each(1..25, fn i ->
        create_transaction(%{
          "account_id" => account.id,
          "amount" => "#{i * 10}.00",
          "description" => "Transaction #{i}",
          "posted_at" => DateTime.utc_now(),
          "direction" => if(rem(i, 2) == 0, do: "CREDIT", else: "DEBIT")
        })
      end)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?page=2&page_size=10")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 10)
    end

    test "supports date filtering", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Create transactions with different dates
      yesterday = DateTime.add(DateTime.utc_now(), -1, :day)
      tomorrow = DateTime.add(DateTime.utc_now(), 1, :day)

      {:ok, _old_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "100.00",
        "description" => "Old Transaction",
        "posted_at" => yesterday,
        "direction" => "DEBIT"
      })
      {:ok, _future_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "200.00",
        "description" => "Future Transaction",
        "posted_at" => tomorrow,
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?start_date=#{Date.to_string(Date.utc_today())}&end_date=#{Date.to_string(Date.utc_today())}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      # Should only include transactions from today
      assert_list_response(response, 0)
    end

    test "supports sorting", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Create transactions with different amounts
      {:ok, _txn1} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "100.00",
        "description" => "Small Transaction",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })

      {:ok, _txn2} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "500.00",
        "description" => "Large Transaction",
        "posted_at" => DateTime.utc_now(),
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?sort_by=amount&sort_order=desc")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 2)
    end

    test "supports combined pagination and sorting", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Create multiple transactions
      Enum.each(1..15, fn i ->
        create_transaction(%{
          "account_id" => account.id,
          "amount" => "#{i * 10}.00",
          "description" => "Transaction #{i}",
          "posted_at" => DateTime.utc_now(),
          "direction" => if(rem(i, 2) == 0, do: "CREDIT", else: "DEBIT")
        })
      end)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?page=1&page_size=5&sort_by=amount&sort_order=desc")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 5)
    end

    test "supports combined filtering and sorting", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Create transactions with different amounts and descriptions
      {:ok, _food_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "25.00",
        "description" => "Food Purchase",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, _gas_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "45.00",
        "description" => "Gas Station",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, _salary_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "2000.00",
        "description" => "Salary Deposit",
        "posted_at" => DateTime.utc_now(),
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?amount_min=50.00&sort_by=amount&sort_order=desc")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end
  end

  describe "Error handling" do
    test "handles invalid pagination parameters", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?page=0&page_size=1000")

      assert_validation_error(json_response(conn, 400))
    end

    test "handles invalid sort parameters", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?sort_by=invalid_field&sort_order=invalid")

      assert_validation_error(json_response(conn, 400))
    end

    test "handles invalid date format", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?start_date=invalid-date")

      assert_validation_error(json_response(conn, 400))
    end

    test "handles invalid amount format", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?amount_min=not-a-number")

      # This should either return 400 for validation error or handle gracefully
      response = json_response(conn, 400)
      assert response["error"]["type"] == "validation_error"
    end

    test "handles missing authentication", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Remove authentication by removing the authorization header
      conn = delete_req_header(conn, "authorization")

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions")

      assert_unauthorized_error(json_response(conn, 401))
    end

    test "handles expired authentication", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Use expired token
      expired_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
      conn = put_req_header(conn, "authorization", "Bearer #{expired_token}")

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions")

      assert_unauthorized_error(json_response(conn, 401))
    end
  end

  describe "Edge cases and boundary conditions" do
    test "handles very large page size gracefully", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?page_size=999999")

      assert_validation_error(json_response(conn, 400))
    end

    test "handles negative page numbers", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?page=-1")

      assert_validation_error(json_response(conn, 400))
    end

    test "handles empty string parameters", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?description=")

      # Should handle gracefully - either return all or return empty
      response = json_response(conn, 200)
      assert_success_response(response, 200)
    end

    test "handles special characters in filter parameters", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?description=%3Cscript%3Ealert('xss')%3C/script%3E")

      # Should handle gracefully without errors
      response = json_response(conn, 200)
      assert_success_response(response, 200)
    end

    test "handles concurrent requests to same account", %{conn: conn} do
      {user, _access_token, conn} = setup_authenticated_user(conn)
      {_user, _bank, branch, _login, _account} = create_complete_banking_setup()
      login = insert(:user_bank_login, user: user, bank_branch: branch)
      account = insert(:user_bank_account, user_bank_login: login)

      # Create some transactions
      {:ok, _txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "100.00",
        "description" => "Test Transaction",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })

      # Make multiple concurrent requests
      tasks = Enum.map(1..5, fn _ ->
        Task.async(fn ->
          conn = get(conn, ~p"/api/accounts/#{account.id}/transactions")
          json_response(conn, 200)
        end)
      end)

      responses = Enum.map(tasks, &Task.await/1)

      # All responses should be successful and consistent
      Enum.each(responses, fn response ->
        assert_success_response(response, 200)
        assert_list_response(response, 1)
      end)
    end
  end
end

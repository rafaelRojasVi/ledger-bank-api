defmodule LedgerBankApiWeb.BankingControllerV2Test do
  @moduledoc """
  Comprehensive tests for BankingControllerV2.
  Tests all banking endpoints: accounts, transactions, balances, payments, and sync operations.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Banking.Context
  alias LedgerBankApi.Banking.Schemas.{Bank, BankBranch, UserBankLogin, UserBankAccount, Transaction, UserPayment}

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

  @valid_user_bank_account_attrs %{
    "currency" => "USD",
    "account_type" => "CHECKING",
    "balance" => "1000.00",
    "last_four" => "1234",
    "account_name" => "Test Account"
  }

  setup do
    # Create test data
    {:ok, bank} = create_bank(@valid_bank_attrs)
    {:ok, bank_branch} = create_bank_branch(Map.put(@valid_bank_branch_attrs, "bank_id", bank.id))

    %{bank: bank, bank_branch: bank_branch}
  end

  describe "GET /api/accounts" do
    test "returns user's accounts", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      # Create user bank account
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

      conn = get(conn, ~p"/api/accounts")

      assert %{
               "data" => [
                 %{
                   "id" => account_id,
                   "account_name" => "Test Account",
                   "currency" => "USD",
                   "account_type" => "CHECKING",
                   "balance" => "1000.00",
                   "last_four" => "1234"
                 }
               ]
             } = json_response(conn, 200)

      assert account_id == account.id
    end

    test "returns only user's own accounts", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create login and account for user1
      {:ok, login1} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user1.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account1} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login1.id
      }))

      # Create login and account for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account2} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login2.id
      }))

      conn = get(conn, ~p"/api/accounts")

      assert %{
               "data" => [
                 %{
                   "id" => account_id,
                   "account_name" => "Test Account"
                 }
               ]
             } = json_response(conn, 200)

      assert account_id == account1.id
      refute account_id == account2.id
    end

    test "returns empty list for user with no accounts", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/accounts")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/accounts/:id" do
    test "returns account details", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account.id}")

      assert %{
               "data" => %{
                 "id" => account_id,
                 "account_name" => "Test Account",
                 "currency" => "USD",
                 "account_type" => "CHECKING",
                 "balance" => "1000.00",
                 "last_four" => "1234"
               }
             } = json_response(conn, 200)

      assert account_id == account.id
    end

    test "returns error for accessing other user's account", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create account for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account2} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login2.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for non-existent account", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/accounts/#{fake_id}")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "GET /api/accounts/:id/transactions" do
    test "returns account transactions", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

      # Create transactions
      {:ok, transaction1} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "100.00",
        "description" => "Test Transaction 1",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, transaction2} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "50.00",
        "description" => "Test Transaction 2",
        "posted_at" => DateTime.utc_now(),
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions")

      assert %{
               "data" => [
                 %{
                   "id" => txn1_id,
                   "amount" => "100.00",
                   "description" => "Test Transaction 1",
                   "direction" => "DEBIT"
                 },
                 %{
                   "id" => txn2_id,
                   "amount" => "50.00",
                   "description" => "Test Transaction 2",
                   "direction" => "CREDIT"
                 }
               ],
               "account" => %{
                 "id" => account_id
               }
             } = json_response(conn, 200)

      assert account_id == account.id
      assert txn1_id == transaction1.id
      assert txn2_id == transaction2.id
    end

    test "returns error for accessing other user's account transactions", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create account for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account2} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login2.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account2.id}/transactions")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end
  end

  describe "GET /api/accounts/:id/balances" do
    test "returns account balance", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account.id}/balances")

      assert %{
               "data" => %{
                 "account_id" => account_id,
                 "balance" => "1000.00",
                 "currency" => "USD"
               }
             } = json_response(conn, 200)

      assert account_id == account.id
    end

    test "returns error for accessing other user's account balance", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create account for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account2} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login2.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account2.id}/balances")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end
  end

  describe "GET /api/accounts/:id/payments" do
    test "returns account payments", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

      # Create payments
      {:ok, payment1} = create_user_payment(%{
        "user_bank_account_id" => account.id,
        "amount" => "200.00",
        "description" => "Test Payment 1",
        "payment_type" => "TRANSFER",
        "status" => "COMPLETED",
        "posted_at" => DateTime.utc_now(),
        "direction" => "DEBIT"
      })
      {:ok, payment2} = create_user_payment(%{
        "user_bank_account_id" => account.id,
        "amount" => "150.00",
        "description" => "Test Payment 2",
        "payment_type" => "PAYMENT",
        "status" => "PENDING",
        "posted_at" => DateTime.utc_now(),
        "direction" => "CREDIT"
      })

      conn = get(conn, ~p"/api/accounts/#{account.id}/payments")

      assert %{
               "data" => [
                 %{
                   "id" => payment1_id,
                   "amount" => "200.00",
                   "description" => "Test Payment 1",
                   "payment_type" => "TRANSFER",
                   "status" => "COMPLETED",
                   "direction" => "DEBIT"
                 },
                 %{
                   "id" => payment2_id,
                   "amount" => "150.00",
                   "description" => "Test Payment 2",
                   "payment_type" => "PAYMENT",
                   "status" => "PENDING",
                   "direction" => "CREDIT"
                 }
               ],
               "account" => %{
                 "id" => account_id
               }
             } = json_response(conn, 200)

      assert account_id == account.id
      assert payment1_id == payment1.id
      assert payment2_id == payment2.id
    end

    test "returns error for accessing other user's account payments", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create account for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account2} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login2.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account2.id}/payments")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end
  end

  describe "POST /api/sync/:login_id" do
    test "queues bank sync job", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = post(conn, ~p"/api/sync/#{login.id}")

      assert %{
               "data" => %{
                 "message" => "bank_sync initiated",
                 "bank_sync_id" => login_id,
                 "status" => "queued"
               }
             } = json_response(conn, 202)

      assert login_id == login.id
    end

    test "returns error for syncing other user's login", %{conn: conn, bank_branch: bank_branch} do
      {user1, _access_token, conn} = setup_authenticated_user(conn)
      {user2, _conn} = create_test_user()

      # Create login for user2
      {:ok, login2} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user2.id,
        "bank_branch_id" => bank_branch.id
      }))

      conn = post(conn, ~p"/api/sync/#{login2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for non-existent login", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = post(conn, ~p"/api/sync/#{fake_id}")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "Pagination, filtering, and sorting" do
    test "supports pagination parameters", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

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

      assert %{
               "data" => transactions,
               "account" => %{"id" => _account_id}
             } = json_response(conn, 200)

      assert length(transactions) == 10
    end

    test "supports date filtering", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

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

      {:ok, _new_txn} = create_transaction(%{
        "account_id" => account.id,
        "amount" => "200.00",
        "description" => "New Transaction",
        "posted_at" => tomorrow,
        "direction" => "CREDIT"
      })

      from_date = DateTime.to_iso8601(DateTime.utc_now())
      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?date_from=#{from_date}")

      assert %{
               "data" => transactions,
               "account" => %{"id" => _account_id}
             } = json_response(conn, 200)

      # Should only return transactions from today onwards
      assert length(transactions) >= 1
    end

    test "supports sorting", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

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

      assert %{
               "data" => [first_txn | _],
               "account" => %{"id" => _account_id}
             } = json_response(conn, 200)

      # First transaction should be the one with higher amount
      assert first_txn["amount"] == "500.00"
    end
  end

  describe "Error handling" do
    test "handles invalid pagination parameters", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?page=0&page_size=1000")

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "handles invalid sort parameters", %{conn: conn, bank_branch: bank_branch} do
      {user, _access_token, conn} = setup_authenticated_user(conn)

      # Create user bank login and account
      {:ok, login} = create_user_bank_login(Map.merge(@valid_user_bank_login_attrs, %{
        "user_id" => user.id,
        "bank_branch_id" => bank_branch.id
      }))
      {:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
        "user_bank_login_id" => login.id
      }))

      conn = get(conn, ~p"/api/accounts/#{account.id}/transactions?sort_by=invalid_field&sort_order=invalid")

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end
end

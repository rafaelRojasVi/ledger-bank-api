defmodule LedgerBankApiWeb.PaymentsControllerV2Test do
  @moduledoc """
  Comprehensive tests for PaymentsControllerV2.
  Tests all payment endpoints: CRUD operations, processing, and account-specific payments.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Banking.Context
  alias LedgerBankApi.Banking.Schemas.{Bank, BankBranch, UserBankLogin, UserBankAccount, UserPayment}

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

  @valid_payment_attrs %{
    "amount" => "100.00",
    "description" => "Test Payment",
    "payment_type" => "TRANSFER",
    "direction" => "DEBIT",
    "posted_at" => DateTime.utc_now()
  }

  @update_payment_attrs %{
    "description" => "Updated Payment",
    "amount" => "150.00"
  }

  setup do
    # Create test data
    {:ok, bank} = create_bank(@valid_bank_attrs)
    {:ok, bank_branch} = create_bank_branch(Map.put(@valid_bank_branch_attrs, "bank_id", bank.id))

    %{bank: bank, bank_branch: bank_branch}
  end

  defp setup_user_with_account(conn, bank_branch) do
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

    {user, account, conn}
  end

  describe "GET /api/payments" do
    test "returns user's payments", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      # Create payments
      {:ok, payment1} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id
      }))
      {:ok, payment2} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "description" => "Second Payment"
      }))

      conn = get(conn, ~p"/api/payments")

      assert %{
               "data" => [
                 %{
                   "id" => payment1_id,
                   "amount" => "100.00",
                   "description" => "Test Payment",
                   "payment_type" => "TRANSFER",
                   "direction" => "DEBIT"
                 },
                 %{
                   "id" => payment2_id,
                   "amount" => "100.00",
                   "description" => "Second Payment",
                   "payment_type" => "TRANSFER",
                   "direction" => "DEBIT"
                 }
               ]
             } = json_response(conn, 200)

      assert payment1_id == payment1.id
      assert payment2_id == payment2.id
    end

    test "returns only user's own payments", %{conn: conn, bank_branch: bank_branch} do
      {user1, account1, conn} = setup_user_with_account(conn, bank_branch)
      {user2, account2, _conn} = setup_user_with_account(build_conn(), bank_branch)

      # Create payment for user1
      {:ok, payment1} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account1.id
      }))

      # Create payment for user2
      {:ok, payment2} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account2.id
      }))

      conn = get(conn, ~p"/api/payments")

      assert %{
               "data" => [
                 %{
                   "id" => payment_id,
                   "description" => "Test Payment"
                 }
               ]
             } = json_response(conn, 200)

      assert payment_id == payment1.id
      refute payment_id == payment2.id
    end

    test "returns empty list for user with no payments", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/payments")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/payments/:id" do
    test "returns payment details", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id
      }))

      conn = get(conn, ~p"/api/payments/#{payment.id}")

      assert %{
               "data" => %{
                 "id" => payment_id,
                 "amount" => "100.00",
                 "description" => "Test Payment",
                 "payment_type" => "TRANSFER",
                 "direction" => "DEBIT",
                 "status" => "PENDING"
               }
             } = json_response(conn, 200)

      assert payment_id == payment.id
    end

    test "returns error for accessing other user's payment", %{conn: conn, bank_branch: bank_branch} do
      {user1, account1, conn} = setup_user_with_account(conn, bank_branch)
      {user2, account2, _conn} = setup_user_with_account(build_conn(), bank_branch)

      # Create payment for user2
      {:ok, payment2} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account2.id
      }))

      conn = get(conn, ~p"/api/payments/#{payment2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for non-existent payment", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/payments/#{fake_id}")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "POST /api/payments" do
    test "creates a new payment", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      payment_attrs = Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id
      })

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      assert %{
               "data" => %{
                 "id" => payment_id,
                 "amount" => "100.00",
                 "description" => "Test Payment",
                 "payment_type" => "TRANSFER",
                 "direction" => "DEBIT",
                 "status" => "PENDING"
               }
             } = json_response(conn, 201)

      assert is_binary(payment_id)

      # Verify payment was created in database
      payment = get_user_payment!(payment_id)
      assert payment.amount == Decimal.new("100.00")
      assert payment.description == "Test Payment"
      assert payment.payment_type == "TRANSFER"
      assert payment.direction == "DEBIT"
      assert payment.status == "PENDING"
    end

    test "returns error for creating payment on other user's account", %{conn: conn, bank_branch: bank_branch} do
      {user1, account1, conn} = setup_user_with_account(conn, bank_branch)
      {user2, account2, _conn} = setup_user_with_account(build_conn(), bank_branch)

      payment_attrs = Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account2.id
      })

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Unauthorized access to account",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for invalid payment data", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      invalid_attrs = %{
        "user_bank_account_id" => account.id,
        "amount" => "-50.00", # Negative amount
        "description" => "Invalid Payment",
        "payment_type" => "INVALID_TYPE",
        "direction" => "INVALID_DIRECTION"
      }

      conn = post(conn, ~p"/api/payments", payment: invalid_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "returns error for missing required fields", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      incomplete_attrs = %{
        "user_bank_account_id" => account.id,
        "description" => "Incomplete Payment"
      }

      conn = post(conn, ~p"/api/payments", payment: incomplete_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end

  describe "PUT /api/payments/:id" do
    test "updates payment", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id
      }))

      conn = put(conn, ~p"/api/payments/#{payment.id}", payment: @update_payment_attrs)

      assert %{
               "data" => %{
                 "id" => payment_id,
                 "amount" => "150.00",
                 "description" => "Updated Payment"
               }
             } = json_response(conn, 200)

      assert payment_id == payment.id

      # Verify database was updated
      updated_payment = get_user_payment!(payment.id)
      assert updated_payment.amount == Decimal.new("150.00")
      assert updated_payment.description == "Updated Payment"
    end

    test "returns error for updating other user's payment", %{conn: conn, bank_branch: bank_branch} do
      {user1, account1, conn} = setup_user_with_account(conn, bank_branch)
      {user2, account2, _conn} = setup_user_with_account(build_conn(), bank_branch)

      # Create payment for user2
      {:ok, payment2} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account2.id
      }))

      conn = put(conn, ~p"/api/payments/#{payment2.id}", payment: @update_payment_attrs)

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for updating completed payment", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "status" => "COMPLETED"
      }))

      conn = put(conn, ~p"/api/payments/#{payment.id}", payment: @update_payment_attrs)

      # This should either return an error or not allow updates to completed payments
      # The exact behavior depends on your business logic
      assert json_response(conn, 400) || json_response(conn, 403)
    end
  end

  describe "DELETE /api/payments/:id" do
    test "deletes payment", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id
      }))

      conn = delete(conn, ~p"/api/payments/#{payment.id}")

      assert response(conn, 204) == ""

      # Verify payment was deleted
      assert_raise Ecto.NoResultsError, fn ->
        get_user_payment!(payment.id)
      end
    end

    test "returns error for deleting other user's payment", %{conn: conn, bank_branch: bank_branch} do
      {user1, account1, conn} = setup_user_with_account(conn, bank_branch)
      {user2, account2, _conn} = setup_user_with_account(build_conn(), bank_branch)

      # Create payment for user2
      {:ok, payment2} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account2.id
      }))

      conn = delete(conn, ~p"/api/payments/#{payment2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for deleting completed payment", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "status" => "COMPLETED"
      }))

      conn = delete(conn, ~p"/api/payments/#{payment.id}")

      # This should return an error for deleting completed payments
      assert json_response(conn, 400) || json_response(conn, 403)
    end
  end

  describe "POST /api/payments/:id/process" do
    test "queues payment processing job", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id
      }))

      conn = post(conn, ~p"/api/payments/#{payment.id}/process")

      assert %{
               "data" => %{
                 "message" => "payment_processing initiated",
                 "payment_processing_id" => payment_id,
                 "status" => "queued"
               }
             } = json_response(conn, 202)

      assert payment_id == payment.id
    end

    test "returns error for processing other user's payment", %{conn: conn, bank_branch: bank_branch} do
      {user1, account1, conn} = setup_user_with_account(conn, bank_branch)
      {user2, account2, _conn} = setup_user_with_account(build_conn(), bank_branch)

      # Create payment for user2
      {:ok, payment2} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account2.id
      }))

      conn = post(conn, ~p"/api/payments/#{payment2.id}/process")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns error for processing non-existent payment", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = post(conn, ~p"/api/payments/#{fake_id}/process")

      assert %{
               "error" => %{
                 "type" => "not_found",
                 "message" => "Resource not found",
                 "code" => 404
               }
             } = json_response(conn, 404)
    end
  end

  describe "GET /api/payments/account/:account_id" do
    test "returns payments for specific account", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      # Create payments for the account
      {:ok, payment1} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id
      }))
      {:ok, payment2} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "description" => "Second Payment"
      }))

      conn = get(conn, ~p"/api/payments/account/#{account.id}")

      assert %{
               "data" => [
                 %{
                   "id" => payment1_id,
                   "description" => "Test Payment"
                 },
                 %{
                   "id" => payment2_id,
                   "description" => "Second Payment"
                 }
               ]
             } = json_response(conn, 200)

      assert payment1_id == payment1.id
      assert payment2_id == payment2.id
    end

    test "returns error for accessing other user's account payments", %{conn: conn, bank_branch: bank_branch} do
      {user1, account1, conn} = setup_user_with_account(conn, bank_branch)
      {user2, account2, _conn} = setup_user_with_account(build_conn(), bank_branch)

      conn = get(conn, ~p"/api/payments/account/#{account2.id}")

      assert %{
               "error" => %{
                 "type" => "forbidden",
                 "message" => "Access forbidden",
                 "code" => 403
               }
             } = json_response(conn, 403)
    end

    test "returns empty list for account with no payments", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      conn = get(conn, ~p"/api/payments/account/#{account.id}")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "Payment validation" do
    test "validates payment types", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      valid_types = ["TRANSFER", "PAYMENT", "DEPOSIT", "WITHDRAWAL"]

      Enum.each(valid_types, fn payment_type ->
        payment_attrs = Map.merge(@valid_payment_attrs, %{
          "user_bank_account_id" => account.id,
          "payment_type" => payment_type
        })

        conn = post(conn, ~p"/api/payments", payment: payment_attrs)
        assert json_response(conn, 201)
      end)
    end

    test "validates payment directions", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      valid_directions = ["CREDIT", "DEBIT"]

      Enum.each(valid_directions, fn direction ->
        payment_attrs = Map.merge(@valid_payment_attrs, %{
          "user_bank_account_id" => account.id,
          "direction" => direction
        })

        conn = post(conn, ~p"/api/payments", payment: payment_attrs)
        assert json_response(conn, 201)
      end)
    end

    test "validates payment statuses", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      valid_statuses = ["PENDING", "COMPLETED", "FAILED", "CANCELLED"]

      Enum.each(valid_statuses, fn status ->
        payment_attrs = Map.merge(@valid_payment_attrs, %{
          "user_bank_account_id" => account.id,
          "status" => status
        })

        conn = post(conn, ~p"/api/payments", payment: payment_attrs)
        assert json_response(conn, 201)
      end)
    end

    test "rejects invalid payment types", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      payment_attrs = Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "payment_type" => "INVALID_TYPE"
      })

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end

    test "rejects negative amounts", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      payment_attrs = Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "amount" => "-50.00"
      })

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      assert %{
               "error" => %{
                 "type" => "validation_error",
                 "message" => "Validation failed",
                 "code" => 400
               }
             } = json_response(conn, 400)
    end
  end

  describe "Payment processing workflow" do
    test "payment status changes during processing", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      # Create a payment
      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "status" => "PENDING"
      }))

      # Verify initial status
      assert payment.status == "PENDING"

      # Process the payment (this would trigger the background job)
      conn = post(conn, ~p"/api/payments/#{payment.id}/process")
      assert json_response(conn, 202)

      # In a real scenario, you would wait for the background job to complete
      # and then verify the status changed to COMPLETED
      # For now, we'll just verify the job was queued successfully
    end

    test "cannot process already completed payment", %{conn: conn, bank_branch: bank_branch} do
      {user, account, conn} = setup_user_with_account(conn, bank_branch)

      # Create a completed payment
      {:ok, payment} = create_user_payment(Map.merge(@valid_payment_attrs, %{
        "user_bank_account_id" => account.id,
        "status" => "COMPLETED"
      }))

      # Try to process it again
      conn = post(conn, ~p"/api/payments/#{payment.id}/process")

      # This should either return an error or be handled gracefully
      # The exact behavior depends on your business logic
      assert json_response(conn, 400) || json_response(conn, 409)
    end
  end
end

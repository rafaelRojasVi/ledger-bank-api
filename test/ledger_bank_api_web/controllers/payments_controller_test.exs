defmodule LedgerBankApiWeb.Controllers.PaymentsControllerTest do
  use LedgerBankApiWeb.ConnCase, async: false
  import LedgerBankApi.BankingFixtures
  import LedgerBankApi.UsersFixtures
  alias LedgerBankApi.Financial.Schemas.UserPayment
  alias LedgerBankApi.Repo
  alias Decimal

  setup %{conn: conn} do
    user = user_fixture()
    login = login_fixture(user)
    account = account_fixture(login, %{balance: Decimal.new("1000.00"), account_type: "CHECKING"})

    # Create a valid JWT token for the user
    {:ok, access_token} = LedgerBankApi.Accounts.Token.generate_access_token(user)

    conn = conn
    |> put_req_header("authorization", "Bearer #{access_token}")
    |> put_req_header("content-type", "application/json")

    %{conn: conn, user: user, login: login, account: account}
  end

  describe "POST /api/payments" do
    test "creates a payment successfully", %{conn: conn, user: user, account: account} do
      payment_params = %{
        "amount" => "100.00",
        "direction" => "DEBIT",
        "payment_type" => "PAYMENT",
        "description" => "Test payment",
        "user_bank_account_id" => account.id
      }

      conn = post(conn, ~p"/api/payments", payment_params)

      assert %{
        "data" => %{
          "id" => payment_id,
          "amount" => "100.00",
          "direction" => "DEBIT",
          "payment_type" => "PAYMENT",
          "description" => "Test payment",
          "status" => "PENDING",
          "user_id" => user_id,
          "user_bank_account_id" => account_id
        },
        "success" => true,
        "metadata" => %{"action" => "created"}
      } = json_response(conn, 201)

      assert payment_id != nil
      assert user_id == user.id
      assert account_id == account.id
    end

    test "returns error for invalid payment parameters", %{conn: conn} do
      invalid_params = %{
        "amount" => "invalid",
        "direction" => "INVALID",
        "payment_type" => "INVALID",
        "description" => "",
        "user_bank_account_id" => "invalid-uuid"
      }

      conn = post(conn, ~p"/api/payments", invalid_params)

      response = json_response(conn, 400)
      assert response["error"]["reason"] == "invalid_amount_format"
      assert response["error"]["category"] == "validation"
      assert response["error"]["status"] == 400
    end

    test "creates payment even with insufficient funds (validation happens during processing)", %{conn: conn, account: account} do
      payment_params = %{
        "amount" => "1500.00",  # More than account balance
        "direction" => "DEBIT",
        "payment_type" => "PAYMENT",
        "description" => "Large payment",
        "user_bank_account_id" => account.id
      }

      conn = post(conn, ~p"/api/payments", payment_params)

      assert %{
        "data" => %{
          "id" => payment_id,
          "amount" => "1500.00",
          "direction" => "DEBIT",
          "status" => "PENDING"
        },
        "success" => true
      } = json_response(conn, 201)

      assert payment_id != nil
    end

    test "returns error for non-existent account", %{conn: conn} do
      payment_params = %{
        "amount" => "100.00",
        "direction" => "DEBIT",
        "payment_type" => "PAYMENT",
        "description" => "Test payment",
        "user_bank_account_id" => Ecto.UUID.generate()
      }

      conn = post(conn, ~p"/api/payments", payment_params)

      response = json_response(conn, 404)
      assert response["error"]["reason"] == "account_not_found"
      assert response["error"]["category"] == "not_found"
      assert response["error"]["status"] == 404
    end
  end

  describe "GET /api/payments" do
    test "lists payments successfully", %{conn: conn, user: user, account: account} do
      # Create some test payments
      _payment1 = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})
      _payment2 = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("200.00"), direction: "CREDIT"})

      conn = get(conn, ~p"/api/payments")

      assert %{
        "data" => payments,
        "success" => true,
        "metadata" => %{
          "action" => "listed",
          "pagination" => pagination
        }
      } = json_response(conn, 200)

      assert length(payments) >= 2
      assert pagination["page"] == 1
      assert pagination["page_size"] == 20
      assert pagination["total_count"] >= 2
    end

    test "filters payments by direction", %{conn: conn, user: user, account: account} do
      # Create test payments
      _debit_payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})
      _credit_payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("200.00"), direction: "CREDIT"})

      conn = get(conn, ~p"/api/payments?direction=DEBIT")

      assert %{
        "data" => payments,
        "success" => true
      } = json_response(conn, 200)

      # All payments should be DEBIT
      Enum.each(payments, fn payment ->
        assert payment["direction"] == "DEBIT"
      end)
    end

    test "filters payments by status", %{conn: conn, user: user, account: account} do
      # Create test payments
      _pending_payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})
      completed_payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("200.00"), direction: "DEBIT"})

      # Mark one as completed
      completed_payment
      |> UserPayment.changeset(%{status: "COMPLETED"})
      |> Repo.update!()

      conn = get(conn, ~p"/api/payments?status=COMPLETED")

      assert %{
        "data" => payments,
        "success" => true
      } = json_response(conn, 200)

      # All payments should be COMPLETED
      Enum.each(payments, fn payment ->
        assert payment["status"] == "COMPLETED"
      end)
    end

    test "supports pagination", %{conn: conn, user: user, account: account} do
      # Create multiple payments
      for i <- 1..5 do
        payment_fixture(account, %{
          user_id: user.id,
          amount: Decimal.new("#{i * 100}.00"),
          direction: "DEBIT"
        })
      end

      conn = get(conn, ~p"/api/payments?page=1&page_size=2")

      assert %{
        "data" => payments,
        "success" => true,
        "metadata" => %{
          "pagination" => pagination
        }
      } = json_response(conn, 200)

      assert length(payments) == 2
      assert pagination["page"] == 1
      assert pagination["page_size"] == 2
    end
  end

  describe "GET /api/payments/:id" do
    test "shows a payment successfully", %{conn: conn, user: user, account: account} do
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      conn = get(conn, ~p"/api/payments/#{payment.id}")

      assert %{
        "data" => %{
          "id" => payment_id,
          "amount" => "100.00",
          "direction" => "DEBIT",
          "status" => "PENDING",
          "user_id" => user_id
        },
        "success" => true,
        "metadata" => %{"action" => "retrieved"}
      } = json_response(conn, 200)

      assert payment_id == payment.id
      assert user_id == user.id
    end

    test "returns error for non-existent payment", %{conn: conn} do
      non_existent_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/payments/#{non_existent_id}")

      response = json_response(conn, 404)
      assert response["error"]["reason"] == "payment_not_found"
      assert response["error"]["category"] == "not_found"
      assert response["error"]["status"] == 404
    end

    test "returns error for invalid UUID", %{conn: conn} do
      conn = get(conn, ~p"/api/payments/invalid-uuid")

      response = json_response(conn, 400)
      assert response["error"]["reason"] == "invalid_uuid_format"
      assert response["error"]["category"] == "validation"
      assert response["error"]["status"] == 400
    end
  end

  describe "POST /api/payments/:id/process" do
    test "processes a payment successfully", %{conn: conn, user: user, account: account} do
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      conn = post(conn, ~p"/api/payments/#{payment.id}/process")

      assert %{
        "data" => %{
          "id" => payment_id,
          "status" => "COMPLETED",
          "posted_at" => posted_at
        },
        "success" => true
      } = json_response(conn, 200)

      assert payment_id == payment.id
      assert posted_at != nil
    end

    test "returns error for already processed payment", %{conn: conn, user: user, account: account} do
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      # Process the payment first
      {:ok, _} = LedgerBankApi.Financial.FinancialService.process_payment(payment.id)

      conn = post(conn, ~p"/api/payments/#{payment.id}/process")

      response = json_response(conn, 403)
      assert response["error"]["reason"] == "insufficient_permissions"
      assert response["error"]["category"] == "authorization"
      assert response["error"]["status"] == 403
    end

    test "returns error for insufficient funds", %{conn: conn, user: user, account: account} do
      # Create payment with amount exceeding account balance
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("1500.00"), direction: "DEBIT"})

      conn = post(conn, ~p"/api/payments/#{payment.id}/process")

      response = json_response(conn, 422)
      assert response["error"]["reason"] == "insufficient_funds"
      assert response["error"]["category"] == "business_rule"
      assert response["error"]["status"] == 422
    end
  end

  describe "GET /api/payments/:id/status" do
    test "returns payment status successfully", %{conn: conn, user: user, account: account} do
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      conn = get(conn, ~p"/api/payments/#{payment.id}/status")

      assert %{
        "data" => %{
          "payment" => %{
            "id" => payment_id,
            "status" => "PENDING"
          },
          "can_process" => true,
          "is_duplicate" => false
        },
        "success" => true,
        "metadata" => %{"action" => "status_retrieved"}
      } = json_response(conn, 200)

      assert payment_id == payment.id
    end

    test "returns error for non-existent payment", %{conn: conn} do
      non_existent_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/payments/#{non_existent_id}/status")

      response = json_response(conn, 404)
      assert response["error"]["reason"] == "payment_not_found"
      assert response["error"]["category"] == "not_found"
      assert response["error"]["status"] == 404
    end
  end

  describe "DELETE /api/payments/:id" do
    test "cancels a pending payment successfully", %{conn: conn, user: user, account: account} do
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      conn = delete(conn, ~p"/api/payments/#{payment.id}")

      assert %{
        "data" => %{
          "id" => payment_id,
          "status" => "CANCELLED"
        },
        "success" => true
      } = json_response(conn, 200)

      assert payment_id == payment.id
    end

    test "returns error for already processed payment", %{conn: conn, user: user, account: account} do
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      # Process the payment first
      {:ok, _} = LedgerBankApi.Financial.FinancialService.process_payment(payment.id)

      conn = delete(conn, ~p"/api/payments/#{payment.id}")

      response = json_response(conn, 403)
      assert response["error"]["reason"] == "insufficient_permissions"
      assert response["error"]["category"] == "authorization"
      assert response["error"]["status"] == 403
    end
  end

  describe "GET /api/payments/stats" do
    test "returns payment statistics successfully", %{conn: conn, user: user, account: account} do
      # Create admin user for stats access
      admin_user = user_fixture(%{role: "admin"})
      {:ok, admin_token} = LedgerBankApi.Accounts.Token.generate_access_token(admin_user)

      # Create some test payments
      payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})
      payment_fixture(account, %{user_id: user.id, amount: Decimal.new("200.00"), direction: "CREDIT"})

      conn = conn
      |> put_req_header("authorization", "Bearer #{admin_token}")
      |> get(~p"/api/payments/stats")

      assert %{
        "data" => %{
          "financial_health" => %{
            "user_id" => user_id,
            "total_balance" => _balance,
            "total_accounts" => _total_accounts,
            "active_accounts" => _active_accounts,
            "is_healthy" => _is_healthy,
            "can_make_payments" => _can_make_payments
          },
          "recent_payments" => recent_payments
        },
        "success" => true,
        "metadata" => %{"action" => "stats_retrieved"}
      } = json_response(conn, 200)

      assert user_id == admin_user.id
      assert is_list(recent_payments)
    end
  end

  describe "POST /api/payments/validate" do
    test "validates a payment successfully", %{conn: conn, account: account} do
      payment_params = %{
        "amount" => "100.00",
        "direction" => "DEBIT",
        "payment_type" => "PAYMENT",
        "description" => "Test payment",
        "user_bank_account_id" => account.id
      }

      conn = post(conn, ~p"/api/payments/validate", payment_params)

      assert %{
        "data" => %{
          "valid" => true,
          "message" => "Payment validation successful",
          "payment" => %{
            "amount" => "100.00",
            "direction" => "DEBIT",
            "payment_type" => "PAYMENT",
            "description" => "Test payment",
            "status" => "PENDING"
          },
          "account" => %{
            "id" => account_id,
            "balance" => _balance
          }
        },
        "success" => true,
        "metadata" => %{"action" => "validated"}
      } = json_response(conn, 200)

      assert account_id == account.id
    end

    test "validates a payment with insufficient funds", %{conn: conn, account: account} do
      payment_params = %{
        "amount" => "1500.00",  # More than account balance
        "direction" => "DEBIT",
        "payment_type" => "PAYMENT",
        "description" => "Large payment",
        "user_bank_account_id" => account.id
      }

      conn = post(conn, ~p"/api/payments/validate", payment_params)

      assert %{
        "data" => %{
          "valid" => false,
          "message" => "Payment validation failed",
          "error" => %{
            "reason" => "insufficient_funds"
          },
          "payment" => %{
            "amount" => "1500.00",
            "direction" => "DEBIT"
          },
          "account" => %{
            "id" => account_id
          }
        },
        "success" => true,
        "metadata" => %{"action" => "validated"}
      } = json_response(conn, 200)

      assert account_id == account.id
    end

    test "returns error for invalid payment parameters", %{conn: conn} do
      invalid_params = %{
        "amount" => "invalid",
        "direction" => "INVALID",
        "payment_type" => "INVALID",
        "description" => "",
        "user_bank_account_id" => "invalid-uuid"
      }

      conn = post(conn, ~p"/api/payments/validate", invalid_params)

      response = json_response(conn, 400)
      assert response["error"]["reason"] == "invalid_amount_format"
      assert response["error"]["category"] == "validation"
      assert response["error"]["status"] == 400
    end
  end

  describe "authorization" do
    test "returns error for unauthenticated requests", %{conn: conn} do
      # Remove authorization header
      conn = put_req_header(conn, "authorization", "")

      conn = get(conn, ~p"/api/payments")

      response = json_response(conn, 401)
      assert response["error"]["reason"] == "invalid_token"
      assert response["error"]["category"] == "authentication"
      assert response["error"]["status"] == 401
    end

    test "returns error for invalid token", %{conn: conn} do
      # Use invalid token
      conn = put_req_header(conn, "authorization", "Bearer invalid-token")

      conn = get(conn, ~p"/api/payments")

      response = json_response(conn, 401)
      assert response["error"]["reason"] == "invalid_token"
      assert response["error"]["category"] == "authentication"
      assert response["error"]["status"] == 401
    end
  end

  describe "correlation ID" do
    test "includes correlation ID in responses", %{conn: conn, user: user, account: account} do
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      conn = get(conn, ~p"/api/payments/#{payment.id}")

      assert %{
        "data" => _data,
        "success" => true,
        "correlation_id" => correlation_id
      } = json_response(conn, 200)

      assert is_binary(correlation_id)
      assert String.length(correlation_id) > 0
    end

    test "uses provided correlation ID from headers", %{conn: conn, user: user, account: account} do
      custom_correlation_id = "custom-correlation-123"
      conn = put_req_header(conn, "x-correlation-id", custom_correlation_id)

      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00"), direction: "DEBIT"})

      conn = get(conn, ~p"/api/payments/#{payment.id}")

      assert %{
        "data" => _data,
        "success" => true,
        "correlation_id" => correlation_id
      } = json_response(conn, 200)

      assert correlation_id == custom_correlation_id
    end
  end
end

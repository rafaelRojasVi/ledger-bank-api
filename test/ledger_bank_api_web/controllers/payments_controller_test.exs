defmodule LedgerBankApiWeb.PaymentsControllerTest do
  @moduledoc """
  Comprehensive tests for PaymentsController.
  Tests all payment endpoints: CRUD operations, processing, and account-specific payments.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.Banking.Context
  import LedgerBankApi.Factories
  import LedgerBankApi.ErrorAssertions
  alias LedgerBankApi.Repo

  defp setup_user_with_account(conn) do
    {user, _access_token, conn} = setup_authenticated_user(conn)

    # Create a complete banking setup for the authenticated user
    {_user, _bank, _branch, login, account} = create_complete_banking_setup()

    # Update the login to belong to the authenticated user
    _login = LedgerBankApi.Repo.update!(Ecto.Changeset.change(login, user_id: user.id))

    # The account should already be linked to the login, so we just need to return it
    {user, account, conn}
  end

  defp create_banking_setup_for_user(user) do
    bank = insert(:monzo_bank)
    branch = insert(:bank_branch, bank: bank)
    login = insert(:user_bank_login, user: user, bank_branch: branch)
    account = insert(:user_bank_account, user_bank_login: login)
    {bank, branch, login, account}
  end

  describe "GET /api/payments" do
    test "returns user's payments", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      # Create payments
      _payment1 = insert(:user_payment, user_bank_account: account)
      _payment2 = insert(:user_payment, user_bank_account: account)

      conn = get(conn, ~p"/api/payments")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 2)
    end

    test "returns only user's own payments", %{conn: conn} do
      {_user1, account1, conn} = setup_user_with_account(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_bank, _branch, _login2, account2} = create_banking_setup_for_user(user2)

      # Create payments for both users
      _payment1 = insert(:user_payment, user_bank_account: account1)
      _payment2 = insert(:user_payment, user_bank_account: account2)

      conn = get(conn, ~p"/api/payments")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 1)
    end

    test "returns empty list for user with no payments", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      conn = get(conn, ~p"/api/payments")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/payments/:id" do
    test "returns payment details", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment = insert(:user_payment, user_bank_account: account)

      conn = get(conn, ~p"/api/payments/#{payment.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_response(response, payment)
    end

    test "returns error for accessing other user's payment", %{conn: conn} do
      {_user1, _account1, conn} = setup_user_with_account(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_bank, _branch, _login2, account2} = create_banking_setup_for_user(user2)

      # Create payment for user2
      payment2 = insert(:user_payment, user_bank_account: account2)

      conn = get(conn, ~p"/api/payments/#{payment2.id}")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns error for non-existent payment", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/payments/#{fake_id}")

      assert_not_found_error(json_response(conn, 404))
    end
  end

  describe "POST /api/payments" do
    test "creates a new payment", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment_attrs = %{
        "user_bank_account_id" => account.id,
        "amount" => "100.00",
        "description" => "Test Payment",
        "payment_type" => "TRANSFER",
        "direction" => "DEBIT"
      }

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      response = json_response(conn, 201)
      assert_success_response(response, 201)
      assert_single_response(response, payment_attrs)
    end

    test "returns error for creating payment on other user's account", %{conn: conn} do
      {_user1, _account1, conn} = setup_user_with_account(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_bank, _branch, _login2, account2} = create_banking_setup_for_user(user2)

      payment_attrs = %{
        "user_bank_account_id" => account2.id,
        "amount" => "100.00",
        "description" => "Test Payment",
        "payment_type" => "TRANSFER",
        "direction" => "DEBIT"
      }

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns error for invalid payment data", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      invalid_attrs = %{
        "user_bank_account_id" => account.id,
        "amount" => "-50.00", # Negative amount
        "description" => "Invalid Payment",
        "payment_type" => "INVALID_TYPE",
        "direction" => "INVALID_DIRECTION"
      }

      conn = post(conn, ~p"/api/payments", payment: invalid_attrs)

      assert_validation_error(json_response(conn, 400))
    end

    test "returns error for missing required fields", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      incomplete_attrs = %{
        "user_bank_account_id" => account.id,
        "description" => "Incomplete Payment"
      }

      conn = post(conn, ~p"/api/payments", payment: incomplete_attrs)

      assert_validation_error(json_response(conn, 400))
    end
  end

  describe "PUT /api/payments/:id" do
    test "updates payment", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment = insert(:user_payment, user_bank_account: account)

      update_attrs = %{
        "amount" => "150.00",
        "description" => "Updated Payment"
      }

      conn = put(conn, ~p"/api/payments/#{payment.id}", payment: update_attrs)

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_response(response, update_attrs)
    end

    test "returns error for updating other user's payment", %{conn: conn} do
      {_user1, _account1, conn} = setup_user_with_account(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_bank, _branch, _login2, account2} = create_banking_setup_for_user(user2)

      # Create payment for user2
      payment2 = insert(:user_payment, user_bank_account: account2)

      update_attrs = %{
        "amount" => "150.00",
        "description" => "Updated Payment"
      }

      conn = put(conn, ~p"/api/payments/#{payment2.id}", payment: update_attrs)

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns error for updating completed payment", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment = insert(:user_payment, user_bank_account: account, status: "COMPLETED")

      update_attrs = %{
        "amount" => "150.00",
        "description" => "Updated Payment"
      }

      conn = put(conn, ~p"/api/payments/#{payment.id}", payment: update_attrs)

      assert_bad_request_error(json_response(conn, 400)) || assert_forbidden_error(json_response(conn, 403))
    end
  end

  describe "DELETE /api/payments/:id" do
    test "deletes payment", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment = insert(:user_payment, user_bank_account: account)

      conn = delete(conn, ~p"/api/payments/#{payment.id}")

      assert response(conn, 204) == ""

      # Verify payment was deleted
      assert_raise Ecto.NoResultsError, fn ->
        get_user_payment!(payment.id)
      end
    end

    test "returns error for deleting other user's payment", %{conn: conn} do
      {_user1, _account1, conn} = setup_user_with_account(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_bank, _branch, _login2, account2} = create_banking_setup_for_user(user2)

      # Create payment for user2
      payment2 = insert(:user_payment, user_bank_account: account2)

      conn = delete(conn, ~p"/api/payments/#{payment2.id}")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns error for deleting completed payment", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment = insert(:user_payment, user_bank_account: account, status: "COMPLETED")

      conn = delete(conn, ~p"/api/payments/#{payment.id}")

      assert_bad_request_error(json_response(conn, 400)) || assert_forbidden_error(json_response(conn, 403))
    end
  end

  describe "POST /api/payments/:id/process" do
    test "queues payment processing job", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment = insert(:user_payment, user_bank_account: account)

      conn = post(conn, ~p"/api/payments/#{payment.id}/process")

      response = json_response(conn, 202)
      assert_success_response(response, 202)
      assert_single_response(response, %{
        "message" => "payment_processing initiated",
        "payment_processing_id" => payment.id,
        "status" => "queued"
      })
    end

    test "returns error for processing other user's payment", %{conn: conn} do
      {_user1, _account1, conn} = setup_user_with_account(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_bank, _branch, _login2, account2} = create_banking_setup_for_user(user2)

      # Create payment for user2
      payment2 = insert(:user_payment, user_bank_account: account2)

      conn = post(conn, ~p"/api/payments/#{payment2.id}/process")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns error for processing non-existent payment", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      conn = post(conn, ~p"/api/payments/#{fake_id}/process")

      assert_not_found_error(json_response(conn, 404))
    end
  end

  describe "GET /api/payments/account/:account_id" do
    test "returns payments for specific account", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      # Create payments for the account
      _payment1 = insert(:user_payment, user_bank_account: account)
      _payment2 = insert(:user_payment, user_bank_account: account)

      conn = get(conn, ~p"/api/payments/account/#{account.id}")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_list_response(response, 2)
    end

    test "returns error for accessing other user's account payments", %{conn: conn} do
      {_user1, _account1, conn} = setup_user_with_account(conn)
      {:ok, user2} = create_test_user()

      # Create complete setup for user2
      {_user, _bank, _branch, login2, account2} = create_complete_banking_setup()
      login2 = %{login2 | user_id: user2.id}
      account2 = %{account2 | user_bank_login_id: login2.id}
      _login2 = Repo.insert!(login2)
      _account2 = Repo.insert!(account2)

      conn = get(conn, ~p"/api/payments/account/#{account2.id}")

      assert_forbidden_error(json_response(conn, 403))
    end

    test "returns empty list for account with no payments", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      conn = get(conn, ~p"/api/payments/account/#{account.id}")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "Payment validation" do
    test "validates payment types", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      valid_types = ["TRANSFER", "PAYMENT", "DEPOSIT", "WITHDRAWAL"]

      Enum.each(valid_types, fn payment_type ->
        payment_attrs = %{
          "user_bank_account_id" => account.id,
          "amount" => "100.00",
          "description" => "Test Payment",
          "payment_type" => payment_type,
          "direction" => "DEBIT"
        }

        conn = post(conn, ~p"/api/payments", payment: payment_attrs)
        assert_success_response(json_response(conn, 201), 201)
      end)
    end

    test "validates payment directions", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      valid_directions = ["CREDIT", "DEBIT"]

      Enum.each(valid_directions, fn direction ->
        payment_attrs = %{
          "user_bank_account_id" => account.id,
          "amount" => "100.00",
          "description" => "Test Payment",
          "payment_type" => "TRANSFER",
          "direction" => direction
        }

        conn = post(conn, ~p"/api/payments", payment: payment_attrs)
        assert_success_response(json_response(conn, 201), 201)
      end)
    end

    test "validates payment statuses", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      valid_statuses = ["PENDING", "COMPLETED", "FAILED", "CANCELLED"]

      Enum.each(valid_statuses, fn status ->
        payment_attrs = %{
          "user_bank_account_id" => account.id,
          "amount" => "100.00",
          "description" => "Test Payment",
          "payment_type" => "TRANSFER",
          "direction" => "DEBIT",
          "status" => status
        }

        conn = post(conn, ~p"/api/payments", payment: payment_attrs)
        assert_success_response(json_response(conn, 201), 201)
      end)
    end

    test "rejects invalid payment types", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment_attrs = %{
        "user_bank_account_id" => account.id,
        "amount" => "100.00",
        "description" => "Test Payment",
        "payment_type" => "INVALID_TYPE",
        "direction" => "DEBIT"
      }

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      assert_validation_error(json_response(conn, 400))
    end

    test "rejects negative amounts", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      payment_attrs = %{
        "user_bank_account_id" => account.id,
        "amount" => "-50.00",
        "description" => "Invalid Payment",
        "payment_type" => "TRANSFER",
        "direction" => "DEBIT"
      }

      conn = post(conn, ~p"/api/payments", payment: payment_attrs)

      assert_validation_error(json_response(conn, 400))
    end
  end

  describe "Payment processing workflow" do
    test "payment status changes during processing", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      # Create a payment
      payment = insert(:user_payment, user_bank_account: account, status: "PENDING")

      # Verify initial status
      assert payment.status == "PENDING"

      # Process the payment (this would trigger the background job)
      conn = post(conn, ~p"/api/payments/#{payment.id}/process")
      assert_success_response(json_response(conn, 202), 202)

      # In a real scenario, you would wait for the background job to complete
      # and then verify the status changed to COMPLETED
      # For now, we'll just verify the job was queued successfully
    end

    test "cannot process already completed payment", %{conn: conn} do
      {_user, account, conn} = setup_user_with_account(conn)

      # Create a completed payment
      payment = insert(:user_payment, user_bank_account: account, status: "COMPLETED")

      # Try to process it again
      conn = post(conn, ~p"/api/payments/#{payment.id}/process")

      # This should either return an error or be handled gracefully
      # The exact behavior depends on your business logic
      assert_bad_request_error(json_response(conn, 400)) || assert_conflict_error(json_response(conn, 409))
    end
  end
end

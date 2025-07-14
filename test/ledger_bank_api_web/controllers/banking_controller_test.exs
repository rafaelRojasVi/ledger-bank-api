defmodule LedgerBankApiWeb.BankingControllerTest do
  use LedgerBankApiWeb.ConnCase, async: true
  import Mimic

  setup :set_mimic_global
  setup :verify_on_exit!

  # Helper to insert a user bank account and preload associations
  defp insert_account_with_assocs() do
    alias LedgerBankApi.Repo
    alias LedgerBankApi.Banking.{Bank, BankBranch, UserBankLogin, UserBankAccount}
    alias LedgerBankApi.Users.User

    user = Repo.insert!(User.changeset(%User{}, %{email: "testuser@example.com", full_name: "Test User", status: "ACTIVE"}))
    bank = Repo.insert!(Bank.changeset(%Bank{}, %{name: "Test Bank", country: "US"}))
    branch = Repo.insert!(BankBranch.changeset(%BankBranch{}, %{name: "Main Branch", iban: "US1234567890", country: "US", bank_id: bank.id}))
    login = Repo.insert!(UserBankLogin.changeset(%UserBankLogin{}, %{user_id: user.id, bank_branch_id: branch.id, username: "testlogin", encrypted_password: "pass"}))
    account = Repo.insert!(UserBankAccount.changeset(%UserBankAccount{}, %{user_bank_login_id: login.id, currency: "USD", account_type: "CHECKING", balance: Decimal.new("100.00"), last_four: "1234", account_name: "Test Checking", status: "ACTIVE"}))
    Repo.preload(account, user_bank_login: [bank_branch: :bank])
  end

  test "GET /api/accounts returns accounts", %{conn: conn} do
    account = insert_account_with_assocs()
    conn = get(conn, "/api/accounts")
    data = json_response(conn, 200)["data"]
    assert is_list(data)
    assert Enum.any?(data, fn acc -> acc["id"] == account.id end)
  end

  test "GET /api/accounts/:id returns account details", %{conn: conn} do
    account = insert_account_with_assocs()
    conn = get(conn, "/api/accounts/#{account.id}")
    data = json_response(conn, 200)["data"]
    assert data["id"] == account.id
    assert data["name"] == account.account_name
  end

  test "GET /api/accounts/:id/transactions returns transactions", %{conn: conn} do
    account = insert_account_with_assocs()
    # Insert a transaction
    alias LedgerBankApi.Banking.Transaction
    LedgerBankApi.Repo.insert!(Transaction.changeset(%Transaction{}, %{account_id: account.id, amount: Decimal.new("-10.00"), posted_at: DateTime.utc_now(), description: "Test Txn"}))
    conn = get(conn, "/api/accounts/#{account.id}/transactions")
    data = json_response(conn, 200)["data"]
    IO.inspect(data, label: "Transactions data")
    assert is_list(data)
    assert Enum.any?(data, fn txn -> txn["account_id"] == account.id end)
  end

  test "GET /api/accounts/:id/transactions paginates transactions", %{conn: conn} do
    account = insert_account_with_assocs()
    alias LedgerBankApi.Banking.Transaction
    # Insert 25 transactions for the account
    for i <- 1..25 do
      LedgerBankApi.Repo.insert!(Transaction.changeset(%Transaction{}, %{
        account_id: account.id,
        amount: Decimal.new("#{-i}.00"),
        posted_at: DateTime.utc_now(),
        description: "Test Txn #{i}"
      }))
    end
    # Request page 2 with page_size 10
    conn = get(conn, "/api/accounts/#{account.id}/transactions", %{page: 2, page_size: 10})
    response = json_response(conn, 200)
    data = response["data"]
    pagination = response["pagination"]

    assert length(data) == 10
    # Ensure the descriptions are for the correct page (transactions 11-20)
    descriptions = Enum.map(data, & &1["description"])
    assert Enum.any?(descriptions, &(&1 == "Test Txn 11"))
    assert Enum.any?(descriptions, &(&1 == "Test Txn 20"))

    # Verify pagination metadata
    assert pagination["page"] == 2
    assert pagination["page_size"] == 10
    assert pagination["total_count"] == 25
    assert pagination["total_pages"] == 3
    assert pagination["has_next"] == true
    assert pagination["has_prev"] == true
  end

  test "GET /api/accounts/:id/balances returns balances", %{conn: conn} do
    account = insert_account_with_assocs()
    conn = get(conn, "/api/accounts/#{account.id}/balances")
    data = json_response(conn, 200)["data"]
    assert data["account_id"] == account.id
    assert data["balance"] == "100.00"
  end

  test "GET /api/accounts/:id/payments returns payments", %{conn: conn} do
    account = insert_account_with_assocs()
    # Insert a payment
    alias LedgerBankApi.Banking.UserPayment
    LedgerBankApi.Repo.insert!(UserPayment.changeset(%UserPayment{}, %{user_bank_account_id: account.id, amount: Decimal.new("20.00"), description: "Test Payment", payment_type: "PAYMENT", status: "COMPLETED", posted_at: DateTime.utc_now()}))
    conn = get(conn, "/api/accounts/#{account.id}/payments")
    data = json_response(conn, 200)["data"]
    assert is_list(data)
    assert Enum.any?(data, fn pay -> pay["account_id"] == account.id end)
  end

  test "GET /api/accounts/:id/transactions with pagination, filtering, and sorting", %{conn: conn} do
    account = insert_account_with_assocs()
    alias LedgerBankApi.Banking.Transaction

    # Insert test transactions with different dates and amounts
    transactions = [
      %{amount: Decimal.new("-10.00"), posted_at: ~U[2025-01-01 10:00:00Z], description: "Coffee"},
      %{amount: Decimal.new("-50.00"), posted_at: ~U[2025-01-02 11:00:00Z], description: "Groceries"},
      %{amount: Decimal.new("-100.00"), posted_at: ~U[2025-01-03 12:00:00Z], description: "Gas"},
      %{amount: Decimal.new("1000.00"), posted_at: ~U[2025-01-04 13:00:00Z], description: "Salary"},
      %{amount: Decimal.new("-25.00"), posted_at: ~U[2025-01-05 14:00:00Z], description: "Lunch"}
    ]

    for txn <- transactions do
      LedgerBankApi.Repo.insert!(Transaction.changeset(%Transaction{}, Map.put(txn, :account_id, account.id)))
    end

    # Test with pagination, filtering, and sorting
    conn = get(conn, "/api/accounts/#{account.id}/transactions", %{
      page: 1,
      page_size: 2,
      date_from: "2025-01-02T00:00:00Z",
      date_to: "2025-01-04T23:59:59Z",
      sort_by: "amount",
      sort_order: "asc"
    })

    response = json_response(conn, 200)
    data = response["data"]
    pagination = response["pagination"]

    # Should return 2 transactions (page_size: 2)
    assert length(data) == 2

    # Should be sorted by amount ascending (smallest amounts first)
    amounts = Enum.map(data, & &1["amount"])
    assert amounts == ["-50.00", "-100.00"]

    # Verify pagination metadata
    assert pagination["page"] == 1
    assert pagination["page_size"] == 2
    assert pagination["total_count"] == 3  # Only 3 transactions in date range
    assert pagination["total_pages"] == 2
    assert pagination["has_next"] == true
    assert pagination["has_prev"] == false
  end

  test "GET /api/accounts/:id/transactions validates invalid parameters", %{conn: conn} do
    account = insert_account_with_assocs()

    # Test invalid page
    conn = get(conn, "/api/accounts/#{account.id}/transactions", %{page: 0})
    assert json_response(conn, 400)["error"] == "Page must be greater than 0"

    # Test invalid page size
    conn = get(conn, "/api/accounts/#{account.id}/transactions", %{page_size: 101})
    assert json_response(conn, 400)["error"] == "Page size cannot exceed 100"

    # Test invalid sort field
    conn = get(conn, "/api/accounts/#{account.id}/transactions", %{sort_by: "invalid_field"})
    assert json_response(conn, 400)["error"] =~ "Invalid sort field"

    # Test invalid date range
    conn = get(conn, "/api/accounts/#{account.id}/transactions", %{
      date_from: "2025-01-02T00:00:00Z",
      date_to: "2025-01-01T00:00:00Z"
    })
    assert json_response(conn, 400)["error"] == "Date from must be before date to"
  end

  defp expect_oban_insert(ids) do
    Oban
    |> expect(:insert, length(ids), fn %Oban.Job{args: %{"user_bank_login_id" => id}} = job ->
      assert id in ids
      {:ok, job}
    end)
  end

  test "enqueues jobs for all ids" do
    ids = ["id1", "id2", "id3"]
    expect_oban_insert(ids)
    for id <- ids do
      Oban.insert(%Oban.Job{
        queue: :banking,
        worker: "LedgerBankApi.Workers.BankSyncWorker",
        args: %{"user_bank_login_id" => id}
      })
    end
  end

  test "collects all job args" do
    Mimic.stub(Oban, :insert, fn job -> {:ok, job} end)
    for id <- ["id1", "id2", "id3"] do
      Oban.insert(%Oban.Job{
        queue: :banking,
        worker: "LedgerBankApi.Workers.BankSyncWorker",
        args: %{"user_bank_login_id" => id}
      })
    end
    calls = Mimic.calls(Oban, :insert, 1)
    assert Enum.map(calls, fn [job] -> job.args["user_bank_login_id"] end) == ["id1", "id2", "id3"]
  end
end

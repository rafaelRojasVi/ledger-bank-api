defmodule LedgerBankApi.BankingTest do
  use LedgerBankApi.DataCase

  alias LedgerBankApi.Banking

  describe "accounts" do
    alias LedgerBankApi.Banking.Account

    import LedgerBankApi.BankingFixtures

    @invalid_attrs %{type: nil, balance: nil, user_id: nil, institution: nil, last4: nil}

    test "list_accounts/0 returns all accounts" do
      account = account_fixture()
      assert Banking.list_accounts() == [account]
    end

    test "get_account!/1 returns the account with given id" do
      account = account_fixture()
      assert Banking.get_account!(account.id) == account
    end

    test "create_account/1 with valid data creates a account" do
      valid_attrs = %{type: "some type", balance: "120.5", user_id: "7488a646-e31f-11e4-aace-600308960662", institution: "some institution", last4: "some last4"}

      assert {:ok, %Account{} = account} = Banking.create_account(valid_attrs)
      assert account.type == "some type"
      assert account.balance == Decimal.new("120.5")
      assert account.user_id == "7488a646-e31f-11e4-aace-600308960662"
      assert account.institution == "some institution"
      assert account.last4 == "some last4"
    end

    test "create_account/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Banking.create_account(@invalid_attrs)
    end

    test "update_account/2 with valid data updates the account" do
      account = account_fixture()
      update_attrs = %{type: "some updated type", balance: "456.7", user_id: "7488a646-e31f-11e4-aace-600308960668", institution: "some updated institution", last4: "some updated last4"}

      assert {:ok, %Account{} = account} = Banking.update_account(account, update_attrs)
      assert account.type == "some updated type"
      assert account.balance == Decimal.new("456.7")
      assert account.user_id == "7488a646-e31f-11e4-aace-600308960668"
      assert account.institution == "some updated institution"
      assert account.last4 == "some updated last4"
    end

    test "update_account/2 with invalid data returns error changeset" do
      account = account_fixture()
      assert {:error, %Ecto.Changeset{}} = Banking.update_account(account, @invalid_attrs)
      assert account == Banking.get_account!(account.id)
    end

    test "delete_account/1 deletes the account" do
      account = account_fixture()
      assert {:ok, %Account{}} = Banking.delete_account(account)
      assert_raise Ecto.NoResultsError, fn -> Banking.get_account!(account.id) end
    end

    test "change_account/1 returns a account changeset" do
      account = account_fixture()
      assert %Ecto.Changeset{} = Banking.change_account(account)
    end
  end

  describe "transactions" do
    alias LedgerBankApi.Banking.Transaction

    import LedgerBankApi.BankingFixtures

    @invalid_attrs %{description: nil, amount: nil, posted_at: nil}

    test "list_transactions/0 returns all transactions" do
      transaction = transaction_fixture()
      assert Banking.list_transactions() == [transaction]
    end

    test "get_transaction!/1 returns the transaction with given id" do
      transaction = transaction_fixture()
      assert Banking.get_transaction!(transaction.id) == transaction
    end

    test "create_transaction/1 with valid data creates a transaction" do
      valid_attrs = %{description: "some description", amount: "120.5", posted_at: ~U[2025-07-10 22:50:00Z]}

      assert {:ok, %Transaction{} = transaction} = Banking.create_transaction(valid_attrs)
      assert transaction.description == "some description"
      assert transaction.amount == Decimal.new("120.5")
      assert transaction.posted_at == ~U[2025-07-10 22:50:00Z]
    end

    test "create_transaction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Banking.create_transaction(@invalid_attrs)
    end

    test "update_transaction/2 with valid data updates the transaction" do
      transaction = transaction_fixture()
      update_attrs = %{description: "some updated description", amount: "456.7", posted_at: ~U[2025-07-11 22:50:00Z]}

      assert {:ok, %Transaction{} = transaction} = Banking.update_transaction(transaction, update_attrs)
      assert transaction.description == "some updated description"
      assert transaction.amount == Decimal.new("456.7")
      assert transaction.posted_at == ~U[2025-07-11 22:50:00Z]
    end

    test "update_transaction/2 with invalid data returns error changeset" do
      transaction = transaction_fixture()
      assert {:error, %Ecto.Changeset{}} = Banking.update_transaction(transaction, @invalid_attrs)
      assert transaction == Banking.get_transaction!(transaction.id)
    end

    test "delete_transaction/1 deletes the transaction" do
      transaction = transaction_fixture()
      assert {:ok, %Transaction{}} = Banking.delete_transaction(transaction)
      assert_raise Ecto.NoResultsError, fn -> Banking.get_transaction!(transaction.id) end
    end

    test "change_transaction/1 returns a transaction changeset" do
      transaction = transaction_fixture()
      assert %Ecto.Changeset{} = Banking.change_transaction(transaction)
    end
  end
end

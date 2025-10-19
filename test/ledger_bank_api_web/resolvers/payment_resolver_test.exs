defmodule LedgerBankApiWeb.Resolvers.PaymentResolverTest do
  use LedgerBankApi.DataCase, async: true

  alias LedgerBankApiWeb.Resolvers.PaymentResolver
  alias LedgerBankApi.Financial.Schemas.UserPayment
  alias LedgerBankApi.Accounts.Schemas.User
  import LedgerBankApi.UsersFixtures
  import LedgerBankApi.BankingFixtures

  describe "find/2" do
    test "returns payment when authenticated" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account)

      args = %{id: payment.id}
      context = %{context: %{current_user: user}}

      assert {:ok, found_payment} = PaymentResolver.find(args, context)
      assert found_payment.id == payment.id
    end

    test "returns error when not authenticated" do
      args = %{id: "some-id"}
      context = %{}

      assert {:error, "Authentication required"} = PaymentResolver.find(args, context)
    end

    test "returns error when payment not found" do
      user = user_fixture()

      args = %{id: "non-existent-id"}
      context = %{context: %{current_user: user}}

      assert {:error, "Payment not found"} = PaymentResolver.find(args, context)
    end
  end

  describe "list/2" do
    test "returns user payments when authenticated" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      _payment1 = payment_fixture(account)
      _payment2 = payment_fixture(account)

      args = %{limit: 10, offset: 0}
      context = %{context: %{current_user: user}}

      assert {:ok, payments} = PaymentResolver.list(args, context)
      assert length(payments) == 2
    end

    test "returns error when not authenticated" do
      args = %{limit: 10, offset: 0}
      context = %{}

      assert {:error, "Authentication required"} = PaymentResolver.list(args, context)
    end
  end

  describe "create/2" do
    test "creates payment when authenticated with valid input" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)

      input = %{
        amount: "100.00",
        direction: "DEBIT",
        payment_type: "PAYMENT",
        description: "Test payment",
        user_bank_account_id: account.id
      }

      args = %{input: input}
      context = %{context: %{current_user: user}}

      assert {:ok, %{success: true, payment: payment}} = PaymentResolver.create(args, context)
      assert payment.amount == Decimal.new("100.00")
      assert payment.direction == "DEBIT"
    end

    test "returns error when not authenticated" do
      input = %{amount: "100.00"}
      args = %{input: input}
      context = %{}

      assert {:error, "Authentication required"} = PaymentResolver.create(args, context)
    end

    test "returns validation errors with invalid input" do
      user = user_fixture()

      input = %{
        amount: "invalid",
        direction: "INVALID"
      }

      args = %{input: input}
      context = %{context: %{current_user: user}}

      assert {:ok, %{success: false, payment: nil, errors: errors}} = PaymentResolver.create(args, context)
      assert length(errors) > 0
    end
  end

  describe "cancel/2" do
    test "cancels payment successfully when authenticated" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account, %{status: "PENDING"})

      args = %{id: payment.id}
      context = %{context: %{current_user: user}}

      assert {:ok, %{success: true, payment: updated_payment}} = PaymentResolver.cancel(args, context)
      assert updated_payment.id == payment.id
    end

    test "returns error when not authenticated" do
      args = %{id: "some-payment-id"}
      context = %{}

      assert {:error, "Authentication required"} = PaymentResolver.cancel(args, context)
    end
  end
end

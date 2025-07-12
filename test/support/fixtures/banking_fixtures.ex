defmodule LedgerBankApi.BankingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LedgerBankApi.Banking` context.
  """

  @doc """
  Generate a account.
  """
  def account_fixture(attrs \\ %{}) do
    {:ok, account} =
      attrs
      |> Enum.into(%{
        balance: "120.5",
        institution: "some institution",
        last4: "some last4",
        type: "some type",
        user_id: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> LedgerBankApi.Banking.create_account()

    account
  end

  @doc """
  Generate a transaction.
  """
  def transaction_fixture(attrs \\ %{}) do
    {:ok, transaction} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        description: "some description",
        posted_at: ~U[2025-07-10 22:50:00Z]
      })
      |> LedgerBankApi.Banking.create_transaction()

    transaction
  end
end

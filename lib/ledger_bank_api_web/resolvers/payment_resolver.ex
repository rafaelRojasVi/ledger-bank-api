defmodule LedgerBankApiWeb.Resolvers.PaymentResolver do
  @moduledoc """
  GraphQL resolvers for payment-related operations.
  """

  require Logger

  alias LedgerBankApi.Financial.FinancialService

  def find(%{id: id}, %{context: %{current_user: _current_user}}) do
    case FinancialService.get_user_payment(id) do
      {:ok, payment} ->
        {:ok, payment}

      {:error, _reason} ->
        {:error, "Payment not found"}
    end
  end

  def find(%{id: _id}, _resolution) do
    {:error, "Authentication required"}
  end

  def list(%{limit: limit, offset: offset}, %{context: %{current_user: current_user}}) do
    {payments, _pagination} =
      FinancialService.list_user_payments(current_user.id, %{limit: limit, offset: offset})

    {:ok, payments}
  end

  def list(_args, _resolution) do
    {:error, "Authentication required"}
  end

  def create(%{input: input}, %{context: %{current_user: current_user}}) do
    # Add user_id to the input
    input_with_user = Map.put(input, :user_id, current_user.id)

    case FinancialService.create_user_payment(input_with_user) do
      {:ok, payment} ->
        # Broadcast real-time notification
        LedgerBankApi.Financial.PaymentNotifications.broadcast_payment_created(payment)

        {:ok, %{success: true, payment: payment, errors: []}}

      {:error, %LedgerBankApi.Core.Error{} = error} ->
        {:ok, %{success: false, payment: nil, errors: [error.message]}}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:ok, %{success: false, payment: nil, errors: errors}}
    end
  end

  def create(_args, _resolution) do
    {:error, "Authentication required"}
  end

  def cancel(%{id: id}, %{context: %{current_user: _current_user}}) do
    case FinancialService.process_payment(id) do
      {:ok, payment} ->
        # Broadcast real-time notification
        LedgerBankApi.Financial.PaymentNotifications.broadcast_payment_status_change(payment)

        {:ok, %{success: true, payment: payment, errors: []}}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)
        {:ok, %{success: false, payment: nil, errors: errors}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel(_args, _resolution) do
    {:error, "Authentication required"}
  end

  # Private helper functions

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} ->
      "#{field}: #{message}"
    end)
  end
end

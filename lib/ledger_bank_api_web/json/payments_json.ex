defmodule LedgerBankApiWeb.PaymentsJSON do
  @moduledoc """
  Optimized payments JSON view using base JSON patterns.
  Provides standardized response formatting for payment endpoints.
  """

  import LedgerBankApiWeb.JSON.BaseJSON

  @doc """
  Renders a list of payments.
  """
  def index(%{payment: payments}) do
    list_response(payments, :payment)
  end

  @doc """
  Renders a single payment.
  """
  def show(%{payment: payment}) do
    show_response(payment, :payment)
  end
end

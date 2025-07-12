# lib/ledger_bank_api_web/controllers/fallback_controller.ex
defmodule LedgerBankApiWeb.FallbackController do
  use LedgerBankApiWeb, :controller

  # If context returns {:error, :not_found}
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Not found"})
  end
end

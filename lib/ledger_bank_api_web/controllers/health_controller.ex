defmodule LedgerBankApiWeb.HealthController do
  @moduledoc """
  Simple health check controller.
  """

  use LedgerBankApiWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: "1.0.0"
    })
  end
end

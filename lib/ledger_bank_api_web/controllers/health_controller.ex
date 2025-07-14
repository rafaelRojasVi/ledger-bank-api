defmodule LedgerBankApiWeb.HealthController do
  use LedgerBankApiWeb, :controller
  require Logger

  @doc """
  Basic health check endpoint.
  """
  def index(conn, _params) do
    case check_health() do
      {:ok, status} ->
        conn
        |> put_status(200)
        |> json(%{
          status: "healthy",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          version: Application.spec(:ledger_bank_api, :vsn),
          checks: status
        })

      {:error, status} ->
        conn
        |> put_status(503)
        |> json(%{
          status: "unhealthy",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          version: Application.spec(:ledger_bank_api, :vsn),
          checks: status
        })
    end
  end

  # Private functions

  defp check_health do
    checks = %{
      database: check_database(),
      external_api: check_external_api()
    }

    case Enum.any?(checks, fn {_key, status} -> status == :error end) do
      true -> {:error, checks}
      false -> {:ok, checks}
    end
  end

  defp check_database do
    try do
      LedgerBankApi.Repo.query!("SELECT 1")
      :ok
    rescue
      e ->
        Logger.error("Database health check failed", error: Exception.message(e))
        :error
    end
  end

  defp check_external_api do
    try do
      # Simple check - in production this would call your external API
      :ok
    rescue
      e ->
        Logger.error("External API health check failed", error: Exception.message(e))
        :error
    end
  end
end

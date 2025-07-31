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
          data: %{
            status: "healthy",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            version: Application.spec(:ledger_bank_api, :vsn),
            checks: status
          }
        })

      {:error, status} ->
        conn
        |> put_status(503)
        |> json(%{
          data: %{
            status: "unhealthy",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            version: Application.spec(:ledger_bank_api, :vsn),
            checks: status
          }
        })
    end
  end

  @doc """
  Detailed health check endpoint with comprehensive service status.
  """
  def detailed(conn, _params) do
    detailed_checks = %{
      database: %{
        status: check_database_status(),
        message: "Database connectivity check"
      },
      cache: %{
        status: check_cache_status(),
        message: "Cache connectivity check"
      },
      external_services: check_external_services()
    }

    conn
    |> put_status(200)
    |> json(%{
      data: %{
        status: "healthy",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        version: Application.spec(:ledger_bank_api, :vsn),
        database: detailed_checks.database,
        cache: detailed_checks.cache,
        external_services: detailed_checks.external_services
      }
    })
  end

  @doc """
  Readiness check endpoint for Kubernetes/container orchestration.
  """
  def ready(conn, _params) do
    ready_status = check_readiness()

    conn
    |> put_status(200)
    |> json(%{
      data: %{
        ready: ready_status,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
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

  defp check_database_status do
    case check_database() do
      :ok -> "ok"
      :error -> "error"
    end
  end

  defp check_cache_status do
    try do
      # Simple cache check - in production this would check Redis/Memcached
      :ok
    rescue
      e ->
        Logger.error("Cache health check failed", error: Exception.message(e))
        :error
    end
    |> case do
      :ok -> "ok"
      :error -> "error"
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

  defp check_external_services do
    [
      %{
        name: "bank_api",
        status: "ok",
        message: "Bank API connectivity"
      },
      %{
        name: "payment_processor",
        status: "ok",
        message: "Payment processor connectivity"
      }
    ]
  end

  defp check_readiness do
    # Check if all critical services are ready
    database_ready = check_database() == :ok
    cache_ready = check_cache_status() == "ok"

    database_ready and cache_ready
  end

  @doc """
  Handle 405 errors for unsupported HTTP methods on health endpoints.
  """
  def method_not_allowed(conn, _params) do
    conn
    |> put_status(405)
    |> json(%{
      error: %{
        type: :method_not_allowed,
        message: "Method not allowed",
        code: 405
      }
    })
  end
end

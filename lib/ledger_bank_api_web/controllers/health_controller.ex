defmodule LedgerBankApiWeb.HealthController do
  @moduledoc """
  Health check controller for monitoring application status.

  Provides endpoints for:
  - Basic health check
  - Database connectivity
  - External service status
  - Application metrics
  """

  use LedgerBankApiWeb, :controller
  require Logger

  @doc """
  Basic health check endpoint.

  GET /health
  """
  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: "1.0.0",
      uptime: get_uptime()
    })
  end

  @doc """
  Detailed health check with database connectivity.

  GET /health/detailed
  """
  def detailed(conn, _params) do
    health_status = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: "1.0.0",
      uptime: get_uptime(),
      checks: %{
        database: check_database(),
        memory: check_memory(),
        disk: check_disk_space()
      }
    }

    # Determine overall status
    overall_status = if all_checks_healthy?(health_status.checks) do
      "ok"
    else
      "degraded"
    end

    status_code = if overall_status == "ok", do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(Map.put(health_status, :status, overall_status))
  end

  @doc """
  Readiness check for load balancers.

  GET /health/ready
  """
  def ready(conn, _params) do
    # Check if application is ready to serve requests
    ready_status = %{
      status: "ready",
      timestamp: DateTime.utc_now(),
      checks: %{
        database: check_database(),
        application: "ok"
      }
    }

    overall_status = if all_checks_healthy?(ready_status.checks) do
      "ready"
    else
      "not_ready"
    end

    status_code = if overall_status == "ready", do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(Map.put(ready_status, :status, overall_status))
  end

  @doc """
  Liveness check for container orchestration.

  GET /health/live
  """
  def live(conn, _params) do
    json(conn, %{
      status: "alive",
      timestamp: DateTime.utc_now(),
      uptime: get_uptime()
    })
  end

  # Private helper functions

  defp get_uptime do
    case :erlang.statistics(:wall_clock) do
      {total_wall_time, _} -> total_wall_time
      _ -> 0
    end
  end

  defp check_database do
    try do
      case LedgerBankApi.Repo.query("SELECT 1", []) do
        {:ok, _} -> "ok"
        {:error, _} -> "error"
      end
    rescue
      _ -> "error"
    end
  end

  defp check_memory do
    try do
      memory_info = :erlang.memory()
      total_memory = memory_info[:total]

      # Check if memory usage is reasonable (< 1GB)
      if total_memory < 1_000_000_000 do
        "ok"
      else
        "warning"
      end
    rescue
      _ -> "error"
    end
  end

  defp check_disk_space do
    try do
      # TODO: Implement proper disk monitoring for production
      "ok"
    rescue
      _ -> "error"
    end
  end

  defp all_checks_healthy?(checks) do
    checks
    |> Map.values()
    |> Enum.all?(fn status -> status == "ok" end)
  end
end

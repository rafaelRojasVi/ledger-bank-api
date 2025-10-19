defmodule LedgerBankApiWeb.Controllers.MetricsController do
  @moduledoc """
  Prometheus metrics controller for monitoring and observability.

  Provides endpoint for Prometheus to scrape application metrics.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  require Logger

  @doc """
  Prometheus metrics endpoint.

  GET /api/metrics
  """
  def index(conn, _params) do
    _context = build_context(conn, :get_metrics)

    try do
      # Get metrics from Prometheus collectors
      metrics = Prometheus.Format.Text.format()

      # Set content type for Prometheus
      conn = put_resp_content_type(conn, "text/plain; version=0.0.4; charset=utf-8")

      # Return metrics in Prometheus format
      text(conn, metrics)
    rescue
      error ->
        Logger.error("Failed to get metrics: #{inspect(error)}")
        context = build_context(conn, :get_metrics, %{error: inspect(error)})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:internal_server_error, context)
        handle_error(conn, error)
    end
  end

  @doc """
  Health check for metrics endpoint.

  GET /api/metrics/health
  """
  def health(conn, _params) do
    _context = build_context(conn, :metrics_health)

    try do
      # Try to get a simple metric to verify Prometheus is working
      _metrics = Prometheus.Format.Text.format()

      health_status = %{
        status: "ok",
        service: "metrics",
        timestamp: DateTime.utc_now(),
        prometheus: "available"
      }

      handle_success(conn, health_status)
    rescue
      error ->
        Logger.error("Metrics health check failed: #{inspect(error)}")
        context = build_context(conn, :metrics_health, %{error: inspect(error)})
        error = LedgerBankApi.Core.ErrorHandler.business_error(:service_unavailable, context)
        handle_error(conn, error)
    end
  end
end

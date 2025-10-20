defmodule LedgerBankApiWeb.Plugs.Tracing do
  @moduledoc """
  OpenTelemetry tracing plug for HTTP requests.

  Automatically creates spans for HTTP requests and extracts/injects
  trace context from/to HTTP headers.
  """

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Tracing temporarily disabled due to OpenTelemetry API issues
    # TODO: Re-enable when OpenTelemetry dependencies are configured
    conn
  end

end

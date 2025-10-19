defmodule LedgerBankApi.Core.Tracing do
  @moduledoc """
  OpenTelemetry tracing utilities for distributed tracing.

  Provides helper functions for creating spans, adding attributes,
  and managing trace context across the application.
  """

  require OpenTelemetry.Tracer
  require Logger

  @doc """
  Start a new span with the given name and attributes.

  ## Examples

      Tracing.with_span("payment_processing", %{payment_id: "pay_123"}) do
        # Payment processing logic
        {:ok, result}
      end

  """
  def with_span(name, attributes \\ %{}, fun) do
    OpenTelemetry.Tracer.with_span(name, %{attributes: attributes}) do
      fun.()
    end
  end

  @doc """
  Start a new span and return the result along with the span context.
  """
  def start_span(name, attributes \\ %{}) do
    span = OpenTelemetry.Tracer.start_span(name, %{attributes: attributes})
    {span, OpenTelemetry.Tracer.current_span_ctx()}
  end

  @doc """
  End a span with the given status.
  """
  def end_span(span, status \\ :ok) do
    case status do
      :ok ->
        OpenTelemetry.Span.set_status(span, :ok)
        OpenTelemetry.Tracer.end_span(span)

      {:error, reason} ->
        OpenTelemetry.Span.set_status(span, {:error, inspect(reason)})
        OpenTelemetry.Span.set_attribute(span, "error", true)
        OpenTelemetry.Span.set_attribute(span, "error.message", inspect(reason))
        OpenTelemetry.Tracer.end_span(span)

      {:error, reason, details} ->
        OpenTelemetry.Span.set_status(span, {:error, inspect(reason)})
        OpenTelemetry.Span.set_attribute(span, "error", true)
        OpenTelemetry.Span.set_attribute(span, "error.message", inspect(reason))
        OpenTelemetry.Span.set_attribute(span, "error.details", inspect(details))
        OpenTelemetry.Tracer.end_span(span)
    end
  end

  @doc """
  Add attributes to the current span.
  """
  def add_attributes(attributes) when is_map(attributes) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      nil -> :ok
      span_ctx ->
        Enum.each(attributes, fn {key, value} ->
          OpenTelemetry.Span.set_attribute(span_ctx, key, value)
        end)
    end
  end

  @doc """
  Add a single attribute to the current span.
  """
  def add_attribute(key, value) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      nil -> :ok
      span_ctx ->
        OpenTelemetry.Span.set_attribute(span_ctx, key, value)
    end
  end

  @doc """
  Add an event to the current span.
  """
  def add_event(name, attributes \\ %{}) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      nil -> :ok
      span_ctx ->
        OpenTelemetry.Span.add_event(span_ctx, name, attributes)
    end
  end

  @doc """
  Create a trace context for external API calls.
  """
  def create_external_call_context(service_name, endpoint) do
    attributes = %{
      "service.name" => service_name,
      "endpoint" => endpoint,
      "call.type" => "external"
    }

    {span, ctx} = start_span("external_api_call", attributes)
    {span, ctx, attributes}
  end

  @doc """
  Trace a database query operation.
  """
  def trace_database_query(query_name, table_name, fun) do
    attributes = %{
      "db.operation" => "query",
      "db.table" => table_name,
      "query.name" => query_name
    }

    with_span("database_query", attributes, fun)
  end

  @doc """
  Trace a business logic operation.
  """
  def trace_business_operation(operation_name, context \\ %{}, fun) do
    attributes = Map.merge(context, %{
      "operation.type" => "business",
      "operation.name" => operation_name
    })

    with_span("business_operation", attributes, fun)
  end

  @doc """
  Trace an authentication operation.
  """
  def trace_auth_operation(operation_type, user_id \\ nil, fun) do
    attributes = %{
      "auth.operation" => operation_type
    }

    attributes = if user_id do
      Map.put(attributes, "user.id", user_id)
    else
      attributes
    end

    with_span("auth_operation", attributes, fun)
  end

  @doc """
  Trace a payment processing operation.
  """
  def trace_payment_operation(operation_type, payment_id, amount \\ nil, fun) do
    attributes = %{
      "payment.operation" => operation_type,
      "payment.id" => payment_id
    }

    attributes = if amount do
      Map.put(attributes, "payment.amount", amount)
    else
      attributes
    end

    with_span("payment_operation", attributes, fun)
  end

  @doc """
  Extract trace context from HTTP headers.
  """
  def extract_trace_context(headers) do
    # Extract W3C trace context headers
    traceparent = get_header(headers, "traceparent")

    case traceparent do
      nil ->
        :ok

      _traceparent_value ->
        # For now, just log that we would extract trace context
        # TODO: Implement proper trace context extraction when OpenTelemetry API is stable
        Logger.debug("Trace context extraction would be performed here")
        :ok
    end
  end

  @doc """
  Inject trace context into HTTP headers.
  """
  def inject_trace_context(headers \\ %{}) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      nil ->
        headers

      _span_ctx ->
        # For now, just return headers as-is
        # TODO: Implement proper trace context injection when OpenTelemetry API is stable
        Logger.debug("Trace context injection would be performed here")
        headers
    end
  end

  # Private helper functions

  defp get_header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(key) == String.downcase(name) do
        value
      else
        nil
      end
    end)
  end

  defp get_header(headers, name) when is_map(headers) do
    Map.get(headers, name) || Map.get(headers, String.downcase(name))
  end
end

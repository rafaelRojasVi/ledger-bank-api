defmodule LedgerBankApiWeb.Plugs.RequestSizeLimit do
  @moduledoc """
  Plug for enforcing request size limits and preventing DoS attacks.

  Limits the size of incoming requests to prevent memory exhaustion
  and protect against malicious large payload attacks.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  require Logger

  # 1MB
  @default_max_body_length 1_048_576
  # 8KB
  @default_max_header_length 8_192
  # 2KB
  @default_max_url_length 2_048

  def init(opts) do
    %{
      max_body_length: Keyword.get(opts, :max_body_length, @default_max_body_length),
      max_header_length: Keyword.get(opts, :max_header_length, @default_max_header_length),
      max_url_length: Keyword.get(opts, :max_url_length, @default_max_url_length),
      skip_paths: Keyword.get(opts, :skip_paths, [])
    }
  end

  def call(conn, opts) do
    if should_skip?(conn.request_path, opts.skip_paths) do
      conn
    else
      conn
      |> validate_url_length(opts.max_url_length)
      |> validate_header_length(opts.max_header_length)
      |> validate_body_length(opts.max_body_length)
    end
  end

  defp should_skip?(path, skip_paths) do
    Enum.any?(skip_paths, fn skip_path ->
      String.starts_with?(path, skip_path)
    end)
  end

  defp validate_url_length(conn, max_length) do
    full_url =
      conn.request_path <>
        if conn.query_string != "", do: "?" <> conn.query_string, else: ""

    if byte_size(full_url) > max_length do
      Logger.warning("Request URL too long: #{byte_size(full_url)} bytes (max: #{max_length})")

      conn
      |> put_status(414)
      |> put_resp_content_type("application/problem+json")
      |> json(%{
        type: "https://api.ledgerbank.com/problems/request_uri_too_long",
        title: "Request URI Too Long",
        status: 414,
        detail: "The request URI exceeds the maximum allowed length of #{max_length} bytes",
        instance: conn.request_path,
        max_url_length: max_length,
        actual_length: byte_size(full_url)
      })
      |> halt()
    else
      conn
    end
  end

  defp validate_header_length(conn, max_length) do
    total_header_length =
      conn.req_headers
      |> Enum.reduce(0, fn {key, value}, acc ->
        # +4 for ": " and "\r\n"
        acc + byte_size(key) + byte_size(value) + 4
      end)

    if total_header_length > max_length do
      Logger.warning(
        "Request headers too long: #{total_header_length} bytes (max: #{max_length})"
      )

      conn
      |> put_status(413)
      |> put_resp_content_type("application/problem+json")
      |> json(%{
        type: "https://api.ledgerbank.com/problems/request_headers_too_large",
        title: "Request Headers Too Large",
        status: 413,
        detail: "The request headers exceed the maximum allowed size of #{max_length} bytes",
        instance: conn.request_path,
        max_header_length: max_length,
        actual_length: total_header_length
      })
      |> halt()
    else
      conn
    end
  end

  defp validate_body_length(conn, max_length) do
    case get_req_header(conn, "content-length") do
      [content_length_str] ->
        case Integer.parse(content_length_str) do
          {content_length, ""} when content_length > max_length ->
            Logger.warning("Request body too large: #{content_length} bytes (max: #{max_length})")

            conn
            |> put_status(413)
            |> put_resp_content_type("application/problem+json")
            |> json(%{
              type: "https://api.ledgerbank.com/problems/request_body_too_large",
              title: "Request Body Too Large",
              status: 413,
              detail: "The request body exceeds the maximum allowed size of #{max_length} bytes",
              instance: conn.request_path,
              max_body_length: max_length,
              actual_length: content_length
            })
            |> halt()

          {_content_length, ""} ->
            conn

          _ ->
            Logger.warning("Invalid content-length header: #{content_length_str}")
            conn
        end

      [] ->
        # No content-length header, which is fine for GET requests
        conn

      _multiple ->
        Logger.warning("Multiple content-length headers found")
        conn
    end
  end

  @doc """
  Configure different size limits for different endpoints.

  ## Examples

      # Allow larger uploads for file endpoints
      plug RequestSizeLimit, [
        max_body_length: 10_485_760,  # 10MB
        skip_paths: ["/api/health"]   # Skip health checks
      ]

  """
  def configure_for_endpoint(endpoint_config) do
    case endpoint_config do
      :file_upload ->
        %{
          # 10MB
          max_body_length: 10_485_760,
          # 16KB
          max_header_length: 16_384,
          # 4KB
          max_url_length: 4_096
        }

      :api_request ->
        %{
          # 1MB
          max_body_length: 1_048_576,
          # 8KB
          max_header_length: 8_192,
          # 2KB
          max_url_length: 2_048
        }

      :webhook ->
        %{
          # 2MB
          max_body_length: 2_097_152,
          # 16KB
          max_header_length: 16_384,
          # 2KB
          max_url_length: 2_048
        }

      _ ->
        %{
          max_body_length: @default_max_body_length,
          max_header_length: @default_max_header_length,
          max_url_length: @default_max_url_length
        }
    end
  end
end

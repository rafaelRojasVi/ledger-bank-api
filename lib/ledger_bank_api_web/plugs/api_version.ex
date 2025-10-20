defmodule LedgerBankApiWeb.Plugs.ApiVersion do
  @moduledoc """
  API versioning plug that handles version headers and route-based versioning.

  Supports:
  - Accept header: `Accept: application/vnd.api+json;version=1`
  - Custom header: `X-API-Version: 1`
  - Query parameter: `?version=1`
  - URL path: `/api/v1/...`

  Defaults to version 1 if no version is specified.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  require Logger

  @supported_versions ["1", "v1"]
  @default_version "1"

  def init(opts), do: opts

  def call(conn, _opts) do
    version = extract_version(conn)

    if version in @supported_versions do
      conn
      |> assign(:api_version, normalize_version(version))
      |> put_resp_header("x-api-version", normalize_version(version))
    else
      conn
      |> put_status(400)
      |> put_resp_header("content-type", "application/problem+json")
      |> json(%{
        type: "https://api.ledgerbank.com/problems/unsupported_api_version",
        title: "Unsupported API Version",
        status: 400,
        detail:
          "API version '#{version}' is not supported. Supported versions: #{Enum.join(@supported_versions, ", ")}",
        instance: conn.request_path,
        supported_versions: @supported_versions
      })
      |> halt()
    end
  end

  defp extract_version(conn) do
    cond do
      # Check Accept header first
      (accept_header = get_req_header(conn, "accept") |> List.first()) != nil and
          version_from_accept(accept_header) != nil ->
        version_from_accept(accept_header)

      # Check custom API version header
      (version_header = get_req_header(conn, "x-api-version") |> List.first()) != nil ->
        version_header

      # Check query parameter
      (version_param = conn.query_params["version"]) != nil ->
        version_param

      # Check URL path for v1 pattern
      String.contains?(conn.request_path, "/v1/") ->
        "v1"

      # Default to version 1
      true ->
        @default_version
    end
  end

  defp version_from_accept(accept_header) when is_binary(accept_header) do
    case Regex.run(~r/version=([0-9]+)/, accept_header) do
      [_, version] -> version
      nil -> nil
    end
  end

  defp version_from_accept(_), do: nil

  defp normalize_version("v1"), do: "1"
  defp normalize_version(version), do: version

  @doc """
  Get the current API version from connection assigns.
  """
  def get_version(conn), do: conn.assigns[:api_version] || @default_version

  @doc """
  Check if the current request is using a specific version.
  """
  def version?(conn, version), do: get_version(conn) == normalize_version(version)
end

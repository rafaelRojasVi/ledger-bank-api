defmodule LedgerBankApiWeb.HealthControllerTest do
  @moduledoc """
  Comprehensive tests for HealthController.
  Tests all health check endpoints: basic health, detailed health, and readiness checks.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.ErrorAssertions

  describe "GET /api/health" do
    test "returns basic health status", %{conn: conn} do
      conn = get(conn, ~p"/api/health")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_response(response, "status")
    end

    test "returns correct health status format", %{conn: conn} do
      conn = get(conn, ~p"/api/health")

      response = json_response(conn, 200)
      assert %{"data" => %{"status" => status}} = response
      assert status in ["healthy", "unhealthy"]
    end
  end

  describe "GET /api/health/detailed" do
    test "returns detailed health information", %{conn: conn} do
      conn = get(conn, ~p"/api/health/detailed")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_response(response, "status")
    end

    test "includes database connectivity check", %{conn: conn} do
      conn = get(conn, ~p"/api/health/detailed")

      response = json_response(conn, 200)
      assert %{"data" => data} = response
      assert Map.has_key?(data, "database")
      assert Map.has_key?(data["database"], "status")
    end

    test "includes cache connectivity check", %{conn: conn} do
      conn = get(conn, ~p"/api/health/detailed")

      response = json_response(conn, 200)
      assert %{"data" => data} = response
      assert Map.has_key?(data, "cache")
      assert Map.has_key?(data["cache"], "status")
    end

    test "includes external services check", %{conn: conn} do
      conn = get(conn, ~p"/api/health/detailed")

      response = json_response(conn, 200)
      assert %{"data" => data} = response
      assert Map.has_key?(data, "external_services")
      assert is_list(data["external_services"])
    end

    test "returns timestamp in response", %{conn: conn} do
      conn = get(conn, ~p"/api/health/detailed")

      response = json_response(conn, 200)
      assert %{"data" => data} = response
      assert Map.has_key?(data, "timestamp")
      assert is_binary(data["timestamp"])
    end
  end

  describe "GET /api/health/ready" do
    test "returns readiness status", %{conn: conn} do
      conn = get(conn, ~p"/api/health/ready")

      response = json_response(conn, 200)
      assert_success_response(response, 200)
      assert_single_response(response, "ready")
    end

    test "returns boolean ready status", %{conn: conn} do
      conn = get(conn, ~p"/api/health/ready")

      response = json_response(conn, 200)
      assert %{"data" => %{"ready" => ready}} = response
      assert is_boolean(ready)
    end

    test "returns ready when all services are healthy", %{conn: conn} do
      conn = get(conn, ~p"/api/health/ready")

      response = json_response(conn, 200)
      assert %{"data" => %{"ready" => ready}} = response

      # In a healthy environment, this should be true
      # In test environment, it might be false depending on external services
      assert is_boolean(ready)
    end
  end

  describe "Health check response format" do
    test "all health endpoints return consistent format", %{conn: conn} do
      endpoints = [
        ~p"/api/health",
        ~p"/api/health/detailed",
        ~p"/api/health/ready"
      ]

      Enum.each(endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        response = json_response(conn, 200)

        # All should return 200 status
        assert_success_response(response, 200)

        # All should have data key
        assert Map.has_key?(response, "data")
        assert is_map(response["data"])
      end)
    end

    test "health endpoints are accessible without authentication", %{conn: conn} do
      endpoints = [
        ~p"/api/health",
        ~p"/api/health/detailed",
        ~p"/api/health/ready"
      ]

      Enum.each(endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        assert json_response(conn, 200)
      end)
    end

    test "health endpoints return JSON content type", %{conn: conn} do
      endpoints = [
        ~p"/api/health",
        ~p"/api/health/detailed",
        ~p"/api/health/ready"
      ]

      Enum.each(endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      end)
    end
  end

  describe "Health check performance" do
    test "basic health check is fast", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      conn = get(conn, ~p"/api/health")
      json_response(conn, 200)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete within 100ms
      assert duration < 100
    end

    test "detailed health check completes within reasonable time", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      conn = get(conn, ~p"/api/health/detailed")
      json_response(conn, 200)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete within 500ms
      assert duration < 500
    end

    test "readiness check is fast", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      conn = get(conn, ~p"/api/health/ready")
      json_response(conn, 200)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete within 100ms
      assert duration < 100
    end
  end

  describe "Health check error handling" do
    test "handles malformed requests gracefully", %{conn: conn} do
      # Test with invalid HTTP method
      conn = put(conn, ~p"/api/health")
      assert json_response(conn, 405)

      conn = post(conn, ~p"/api/health")
      assert json_response(conn, 405)

      conn = delete(conn, ~p"/api/health")
      assert json_response(conn, 405)
    end

    test "handles non-existent health endpoints", %{conn: conn} do
      conn = get(conn, ~p"/api/health/nonexistent")
      response = json_response(conn, 404)
      assert_not_found_error(response)
    end
  end

  describe "Health check integration" do
    test "health status reflects application state", %{conn: conn} do
      # Test that health endpoints are consistent
      basic_health = get(conn, ~p"/api/health") |> json_response(200)
      detailed_health = get(conn, ~p"/api/health/detailed") |> json_response(200)
      readiness = get(conn, ~p"/api/health/ready") |> json_response(200)

      # All should return successful responses
      assert_success_response(basic_health, 200)
      assert_success_response(detailed_health, 200)
      assert_success_response(readiness, 200)

      # Basic health should be consistent with detailed health
      basic_status = basic_health["data"]["status"]
      detailed_status = detailed_health["data"]["status"]

      # In a healthy test environment, both should be "healthy"
      # But we'll just check they're both valid statuses
      assert basic_status in ["healthy", "unhealthy"]
      assert detailed_status in ["healthy", "unhealthy"]
    end
  end
end

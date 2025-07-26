defmodule LedgerBankApiWeb.HealthControllerV2Test do
  @moduledoc """
  Comprehensive tests for HealthControllerV2.
  Tests all health check endpoints: basic health, detailed health, and system status.
  """

  use LedgerBankApiWeb.ConnCase

  describe "GET /health" do
    test "returns basic health status", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert %{
               "status" => "healthy",
               "timestamp" => timestamp,
               "version" => version
             } = json_response(conn, 200)

      assert is_binary(timestamp)
      assert is_binary(version)
    end

    test "returns consistent response format", %{conn: conn} do
      conn = get(conn, ~p"/health")

      response = json_response(conn, 200)

      # Verify all required fields are present
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "timestamp")
      assert Map.has_key?(response, "version")

      # Verify status is always "healthy" when system is running
      assert response["status"] == "healthy"
    end

    test "returns valid timestamp format", %{conn: conn} do
      conn = get(conn, ~p"/health")

      %{"timestamp" => timestamp} = json_response(conn, 200)

      # Verify timestamp is in ISO8601 format
      assert {:ok, _datetime} = DateTime.from_iso8601(timestamp)
    end
  end

  describe "GET /health/detailed" do
    test "returns detailed health information", %{conn: conn} do
      conn = get(conn, ~p"/health/detailed")

      assert %{
               "status" => "healthy",
               "timestamp" => timestamp,
               "version" => version,
               "services" => %{
                 "database" => %{
                   "status" => "healthy",
                   "response_time" => db_response_time
                 },
                 "cache" => %{
                   "status" => "healthy",
                   "response_time" => cache_response_time
                 }
               },
               "system" => %{
                 "uptime" => uptime,
                 "memory_usage" => memory_usage,
                 "cpu_usage" => cpu_usage
               }
             } = json_response(conn, 200)

      assert is_binary(timestamp)
      assert is_binary(version)
      assert is_number(db_response_time)
      assert is_number(cache_response_time)
      assert is_number(uptime)
      assert is_number(memory_usage)
      assert is_number(cpu_usage)
    end

    test "includes all required service checks", %{conn: conn} do
      conn = get(conn, ~p"/health/detailed")

      response = json_response(conn, 200)

      # Verify services section exists
      assert Map.has_key?(response, "services")
      services = response["services"]

      # Verify database service check
      assert Map.has_key?(services, "database")
      db_service = services["database"]
      assert Map.has_key?(db_service, "status")
      assert Map.has_key?(db_service, "response_time")

      # Verify cache service check
      assert Map.has_key?(services, "cache")
      cache_service = services["cache"]
      assert Map.has_key?(cache_service, "status")
      assert Map.has_key?(cache_service, "response_time")
    end

    test "includes system metrics", %{conn: conn} do
      conn = get(conn, ~p"/health/detailed")

      response = json_response(conn, 200)

      # Verify system section exists
      assert Map.has_key?(response, "system")
      system = response["system"]

      # Verify system metrics
      assert Map.has_key?(system, "uptime")
      assert Map.has_key?(system, "memory_usage")
      assert Map.has_key?(system, "cpu_usage")

      # Verify metrics are reasonable values
      assert system["uptime"] >= 0
      assert system["memory_usage"] >= 0
      assert system["memory_usage"] <= 100
      assert system["cpu_usage"] >= 0
      assert system["cpu_usage"] <= 100
    end

    test "database service check works", %{conn: conn} do
      conn = get(conn, ~p"/health/detailed")

      %{"services" => %{"database" => db_service}} = json_response(conn, 200)

      # Verify database is healthy
      assert db_service["status"] == "healthy"

      # Verify response time is reasonable (should be fast for local tests)
      assert db_service["response_time"] < 1000 # Less than 1 second
    end

    test "cache service check works", %{conn: conn} do
      conn = get(conn, ~p"/health/detailed")

      %{"services" => %{"cache" => cache_service}} = json_response(conn, 200)

      # Verify cache is healthy
      assert cache_service["status"] == "healthy"

      # Verify response time is reasonable
      assert cache_service["response_time"] < 1000 # Less than 1 second
    end
  end

  describe "GET /health/ready" do
    test "returns ready status when all services are healthy", %{conn: conn} do
      conn = get(conn, ~p"/health/ready")

      assert %{
               "status" => "ready",
               "timestamp" => timestamp,
               "checks" => %{
                 "database" => "healthy",
                 "cache" => "healthy"
               }
             } = json_response(conn, 200)

      assert is_binary(timestamp)
    end

    test "returns consistent ready response format", %{conn: conn} do
      conn = get(conn, ~p"/health/ready")

      response = json_response(conn, 200)

      # Verify all required fields are present
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "timestamp")
      assert Map.has_key?(response, "checks")

      # Verify status is "ready" when system is healthy
      assert response["status"] == "ready"

      # Verify checks section
      checks = response["checks"]
      assert Map.has_key?(checks, "database")
      assert Map.has_key?(checks, "cache")
    end

    test "includes all required health checks", %{conn: conn} do
      conn = get(conn, ~p"/health/ready")

      %{"checks" => checks} = json_response(conn, 200)

      # Verify all expected checks are present
      assert Map.has_key?(checks, "database")
      assert Map.has_key?(checks, "cache")

      # Verify all checks are healthy
      assert checks["database"] == "healthy"
      assert checks["cache"] == "healthy"
    end
  end

  describe "GET /health/live" do
    test "returns live status when application is running", %{conn: conn} do
      conn = get(conn, ~p"/health/live")

      assert %{
               "status" => "alive",
               "timestamp" => timestamp,
               "pid" => pid
             } = json_response(conn, 200)

      assert is_binary(timestamp)
      assert is_binary(pid)
    end

    test "returns consistent live response format", %{conn: conn} do
      conn = get(conn, ~p"/health/live")

      response = json_response(conn, 200)

      # Verify all required fields are present
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "timestamp")
      assert Map.has_key?(response, "pid")

      # Verify status is "alive" when application is running
      assert response["status"] == "alive"
    end

    test "includes valid process ID", %{conn: conn} do
      conn = get(conn, ~p"/health/live")

      %{"pid" => pid} = json_response(conn, 200)

      # Verify PID is a valid format (should be a string representation)
      assert is_binary(pid)
      assert String.length(pid) > 0
    end
  end

  describe "Health check performance" do
    test "basic health check is fast", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)

      conn = get(conn, ~p"/health")

      end_time = System.monotonic_time(:millisecond)
      response_time = end_time - start_time

      # Basic health check should be very fast
      assert response_time < 100 # Less than 100ms
      assert json_response(conn, 200)
    end

    test "detailed health check includes response times", %{conn: conn} do
      conn = get(conn, ~p"/health/detailed")

      %{"services" => services} = json_response(conn, 200)

      # Verify response times are included and reasonable
      assert services["database"]["response_time"] >= 0
      assert services["cache"]["response_time"] >= 0

      # Response times should be reasonable for local tests
      assert services["database"]["response_time"] < 1000
      assert services["cache"]["response_time"] < 1000
    end
  end

  describe "Health check consistency" do
    test "multiple health checks return consistent status", %{conn: conn} do
      # Make multiple health check requests
      responses = for _ <- 1..5 do
        conn = get(conn, ~p"/health")
        json_response(conn, 200)
      end

      # All responses should have the same status
      statuses = Enum.map(responses, & &1["status"])
      assert Enum.all?(statuses, fn status -> status == "healthy" end)
    end

    test "health checks return valid JSON", %{conn: conn} do
      endpoints = ["/health", "/health/detailed", "/health/ready", "/health/live"]

      Enum.each(endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        response = json_response(conn, 200)

        # Verify response is a valid map (JSON object)
        assert is_map(response)
        assert map_size(response) > 0
      end)
    end
  end

  describe "Error handling in health checks" do
    test "health checks handle concurrent requests", %{conn: conn} do
      # Make concurrent health check requests
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          conn = get(build_conn(), ~p"/health")
          json_response(conn, 200)
        end)
      end

      responses = Task.await_many(tasks)

      # All responses should be successful
      assert length(responses) == 10
      Enum.each(responses, fn response ->
        assert response["status"] == "healthy"
      end)
    end

    test "health checks are idempotent", %{conn: conn} do
      # Make the same health check request multiple times
      responses = for _ <- 1..3 do
        conn = get(conn, ~p"/health/detailed")
        json_response(conn, 200)
      end

      # All responses should be identical in structure
      [first_response | other_responses] = responses

      Enum.each(other_responses, fn response ->
        assert Map.keys(response) == Map.keys(first_response)
        assert response["status"] == first_response["status"]
      end)
    end
  end

  describe "Health check metadata" do
    test "includes application version", %{conn: conn} do
      conn = get(conn, ~p"/health")

      %{"version" => version} = json_response(conn, 200)

      # Version should be a non-empty string
      assert is_binary(version)
      assert String.length(version) > 0
    end

    test "includes timestamps in all health endpoints", %{conn: conn} do
      endpoints = ["/health", "/health/detailed", "/health/ready", "/health/live"]

      Enum.each(endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        response = json_response(conn, 200)

        assert Map.has_key?(response, "timestamp")
        assert is_binary(response["timestamp"])

        # Verify timestamp is valid ISO8601
        assert {:ok, _datetime} = DateTime.from_iso8601(response["timestamp"])
      end)
    end
  end
end

defmodule LedgerBankApiWeb.HealthControllerTest do
  use LedgerBankApiWeb.ConnCase, async: false

  describe "GET /api/health" do
    test "returns basic health status", %{conn: conn} do
      conn = get(conn, "/api/health")

      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["version"] == "1.0.0"
      assert is_binary(response["timestamp"])
      assert is_integer(response["uptime"])
    end
  end

  describe "GET /api/health/detailed" do
    test "returns detailed health status", %{conn: conn} do
      conn = get(conn, "/api/health/detailed")

      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["version"] == "1.0.0"
      assert response["uptime"] >= 0
      assert is_map(response["checks"])
      assert response["checks"]["database"] == "ok"
      assert response["checks"]["memory"] in ["ok", "warning"]
      assert response["checks"]["disk"] == "ok"
    end
  end

  describe "GET /api/health/ready" do
    test "returns readiness status", %{conn: conn} do
      conn = get(conn, "/api/health/ready")

      response = json_response(conn, 200)

      assert response["status"] == "ready"
      assert is_map(response["checks"])
      assert response["checks"]["database"] == "ok"
      assert response["checks"]["application"] == "ok"
    end
  end

  describe "GET /api/health/live" do
    test "returns liveness status", %{conn: conn} do
      conn = get(conn, "/api/health/live")

      response = json_response(conn, 200)

      assert response["status"] == "alive"
      assert response["uptime"] >= 0
    end
  end
end

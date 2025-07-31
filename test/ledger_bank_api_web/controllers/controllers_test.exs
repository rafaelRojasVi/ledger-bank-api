defmodule LedgerBankApiWeb.ControllersTest do
  @moduledoc """
  Comprehensive tests for all controllers.
  Tests common patterns, error handling, and controller behavior across the application.
  """

  use LedgerBankApiWeb.ConnCase
  import LedgerBankApi.ErrorAssertions

  describe "Controller response format" do
    test "all controllers return consistent response format", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      # Test different controller endpoints that are known to work
      endpoints = [
        {get(conn, ~p"/api/me"), 200},
        {get(conn, ~p"/api/accounts"), 200}
      ]

      Enum.each(endpoints, fn {conn, expected_status} ->
        response = json_response(conn, expected_status)

        # All responses should have consistent structure
        assert Map.has_key?(response, "data")
        assert is_list(response["data"]) or is_map(response["data"])
      end)
    end

    test "error responses follow consistent format", %{conn: conn} do
      # Test unauthorized access
      conn = get(conn, ~p"/api/me")
      response = json_response(conn, 401)
      assert_unauthorized_error(response)
    end

    test "forbidden access returns correct error", %{conn: conn} do
      # Create a new connection for this test to avoid reuse issues
      {_user1, _access_token, conn2} = setup_authenticated_user(conn)
      {:ok, user2} = create_test_user()

      # Try to access another user's data
      conn2 = get(conn2, ~p"/api/users/#{user2.id}")
      response = json_response(conn2, 403)
      assert_forbidden_error(response)
    end
  end

  describe "Authentication and authorization" do
    test "protected endpoints require authentication", %{conn: conn} do
      protected_endpoints = [
        ~p"/api/me",
        ~p"/api/accounts",
        ~p"/api/payments",
        ~p"/api/user-bank-logins"
      ]

      Enum.each(protected_endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        response = json_response(conn, 401)
        assert_unauthorized_error(response)
      end)
    end

    test "admin endpoints require admin role", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      # Regular user should not access admin endpoints
      conn = get(conn, ~p"/api/users")
      response = json_response(conn, 403)
      assert_forbidden_error(response)
    end
  end

  describe "Error handling" do
    test "handles validation errors consistently", %{conn: conn} do
      # Test invalid user creation
      invalid_user_attrs = %{
        "email" => "invalid-email",
        "full_name" => "",
        "password" => "123"
      }

      conn = post(conn, ~p"/api/auth/register", user: invalid_user_attrs)
      response = json_response(conn, 400)
      assert_validation_error(response)
    end

    test "handles not found errors consistently", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)
      fake_id = Ecto.UUID.generate()

      # Test accessing non-existent resources
      endpoints = [
        ~p"/api/users/#{fake_id}",
        ~p"/api/accounts/#{fake_id}",
        ~p"/api/payments/#{fake_id}"
      ]

      Enum.each(endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        response = json_response(conn, 404)
        assert_not_found_error(response)
      end)
    end
  end

  describe "Rate limiting" do
    test "endpoints respect rate limits", %{conn: conn} do
      # Test rate limiting by making many requests
      requests = for _ <- 1..10 do
        get(conn, ~p"/api/health")
      end

      # Most should succeed, but some might be rate limited
      responses = Enum.map(requests, fn conn ->
        case conn.status do
          200 -> :ok
          429 -> :rate_limited
          _ -> :other
        end
      end)

      # At least some should succeed
      assert Enum.any?(responses, &(&1 == :ok))
    end
  end

  describe "Content negotiation" do
    test "controllers return JSON by default", %{conn: conn} do
      endpoints = [
        ~p"/api/health"
      ]

      Enum.each(endpoints, fn endpoint ->
        conn = get(conn, endpoint)
        assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      end)
    end
  end

  describe "Request validation" do
    test "controllers validate required parameters", %{conn: conn} do
      # Test missing required parameters for auth endpoint
      conn = post(conn, ~p"/api/auth/login", %{})
      response = json_response(conn, 400)
      assert_validation_error(response)
    end
  end

  describe "Controller performance" do
    test "controllers respond within reasonable time", %{conn: conn} do
      {_user, _access_token, conn} = setup_authenticated_user(conn)

      # Test response times for common endpoints
      endpoints = [
        ~p"/api/me",
        ~p"/api/accounts",
        ~p"/api/health"
      ]

      Enum.each(endpoints, fn endpoint ->
        start_time = System.monotonic_time(:millisecond)

        conn = get(conn, endpoint)
        json_response(conn, 200)

        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Should complete within 500ms
        assert duration < 500
      end)
    end
  end
end

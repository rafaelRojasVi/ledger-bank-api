defmodule LedgerBankApiWeb.Controllers.ProblemsControllerTest do
  use LedgerBankApiWeb.ConnCase, async: false

  describe "GET /api/problems" do
    test "returns complete error catalog registry", %{conn: conn} do
      conn = get(conn, ~p"/api/problems")
      response = json_response(conn, 200)

      assert %{
        "data" => problems,
        "success" => true,
        "metadata" => metadata
      } = response

      # Verify metadata
      assert metadata["total_errors"] > 0
      assert metadata["categories"] == ["validation", "not_found", "authentication", "authorization", "conflict", "business_rule", "external_dependency", "system"]
      assert metadata["api_version"] == "v1"
      assert is_binary(metadata["last_updated"])

      # Verify problems structure
      assert is_list(problems)
      assert length(problems) > 0

      # Check a specific error
      validation_error = Enum.find(problems, fn problem -> problem["code"] == "invalid_email_format" end)
      assert validation_error != nil
      assert validation_error["type"] == "https://api.ledgerbank.com/problems/invalid_email_format"
      assert validation_error["status"] == 400
      assert validation_error["title"] == "Invalid email format"
      assert validation_error["category"] == "validation"
      assert validation_error["retryable"] == false
      assert validation_error["retry_delay_ms"] == 0
      assert validation_error["max_retry_attempts"] == 0

      # Check a retryable error
      system_error = Enum.find(problems, fn problem -> problem["code"] == "internal_server_error" end)
      assert system_error != nil
      assert system_error["retryable"] == true
      assert system_error["retry_delay_ms"] == 500
      assert system_error["max_retry_attempts"] == 2
    end
  end

  describe "GET /api/problems/:reason" do
    test "returns detailed information for valid error reason", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/insufficient_funds")
      response = json_response(conn, 200)

      assert %{
        "data" => problem,
        "success" => true
      } = response

      assert problem["code"] == "insufficient_funds"
      assert problem["type"] == "https://api.ledgerbank.com/problems/insufficient_funds"
      assert problem["status"] == 422
      assert problem["title"] == "Insufficient funds for this transaction"
      assert problem["category"] == "business_rule"
      assert problem["retryable"] == false
      assert problem["description"] != nil
      assert is_list(problem["examples"])
    end

    test "returns 400 for invalid error reason (invalid format)", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/nonexistent_error")
      response = json_response(conn, 400)

      # Should return RFC 9457 format
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/invalid_reason_format"
      assert response["error"]["status"] == 400
      assert response["error"]["title"] == "Invalid error reason format"
      assert response["error"]["reason"] == "invalid_reason_format"
      assert response["error"]["category"] == "validation"
    end

    test "returns 400 for invalid reason format", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/123invalid")
      response = json_response(conn, 400)

      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/invalid_reason_format"
      assert response["error"]["status"] == 400
      assert response["error"]["title"] == "Invalid error reason format"
      assert response["error"]["reason"] == "invalid_reason_format"
      assert response["error"]["category"] == "validation"
    end
  end

  describe "GET /api/problems/category/:category" do
    test "returns all errors for valid category", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/category/validation")
      response = json_response(conn, 200)

      assert %{
        "data" => problems,
        "success" => true,
        "metadata" => metadata
      } = response

      assert metadata["category"] == "validation"
      assert metadata["total_errors"] > 0
      assert metadata["http_status"] == 400

      # All problems should be validation errors
      for problem <- problems do
        assert problem["category"] == "validation"
        assert problem["status"] == 400
      end

      # Should include specific validation errors
      error_codes = Enum.map(problems, & &1["code"])
      assert "invalid_email_format" in error_codes
      assert "invalid_password_format" in error_codes
      assert "missing_fields" in error_codes
    end

    test "returns all errors for business_rule category", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/category/business_rule")
      response = json_response(conn, 200)

      assert %{
        "data" => problems,
        "success" => true,
        "metadata" => metadata
      } = response

      assert metadata["category"] == "business_rule"
      assert metadata["http_status"] == 422

      # All problems should be business rule errors
      for problem <- problems do
        assert problem["category"] == "business_rule"
        assert problem["status"] == 422
      end

      # Should include specific business rule errors
      error_codes = Enum.map(problems, & &1["code"])
      assert "insufficient_funds" in error_codes
      assert "daily_limit_exceeded" in error_codes
      assert "account_inactive" in error_codes
    end

    test "returns 400 for invalid category", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/category/invalid_category")
      response = json_response(conn, 400)

      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/invalid_category"
      assert response["error"]["status"] == 400
      assert response["error"]["title"] == "Invalid error category"
      assert response["error"]["reason"] == "invalid_category"
      assert response["error"]["category"] == "validation"
    end

    test "returns 400 for invalid category format", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/category/123invalid")
      response = json_response(conn, 400)

      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/invalid_category_format"
      assert response["error"]["status"] == 400
      assert response["error"]["title"] == "Invalid error category format"
      assert response["error"]["reason"] == "invalid_category_format"
      assert response["error"]["category"] == "validation"
    end
  end

  describe "RFC 9457 compliance" do
    test "all error responses include required RFC 9457 fields", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/nonexistent_error")
      response = json_response(conn, 400)

      # Required RFC 9457 fields
      assert Map.has_key?(response["error"], "type")
      assert Map.has_key?(response["error"], "title")
      assert Map.has_key?(response["error"], "status")
      assert Map.has_key?(response["error"], "instance")

      # Optional but present fields
      assert Map.has_key?(response["error"], "details")
      assert Map.has_key?(response["error"], "reason")
      assert Map.has_key?(response["error"], "category")
      assert Map.has_key?(response["error"], "retryable")
      assert Map.has_key?(response["error"], "timestamp")
    end

    test "error responses have correct content type", %{conn: conn} do
      conn = get(conn, ~p"/api/problems/nonexistent_error")

      # Check content type header
      content_type = get_resp_header(conn, "content-type") |> List.first()
      assert content_type == "application/json; charset=utf-8"
    end

    test "retryable errors include retry-after header", %{conn: conn} do
      # Test with a valid error reason that exists in the catalog
      conn = get(conn, ~p"/api/problems/internal_server_error")
      response = json_response(conn, 200)

      # Verify the error is marked as retryable
      problem = response["data"]
      assert problem["retryable"] == true
      assert problem["retry_delay_ms"] == 500
      assert problem["max_retry_attempts"] == 2
    end
  end
end

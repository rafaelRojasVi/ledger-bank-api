defmodule LedgerBankApi.ErrorAssertions do
  @moduledoc """
  Flexible error assertion helpers for testing error responses.
  Focuses on structure and type rather than exact message strings.
  """

  import ExUnit.Assertions

  @doc """
  Asserts that a response contains an error with the expected type and status code.
  More flexible than testing exact message strings.
  """
  def assert_error_response(response, expected_type, expected_status_code) do
    assert %{"error" => error} = response
    assert error["type"] == expected_type
    assert error["code"] == expected_status_code
    assert is_binary(error["message"])
    assert String.length(error["message"]) > 0
  end

  @doc """
  Asserts that a response contains an unauthorized error.
  """
  def assert_unauthorized_error(response) do
    assert_error_response(response, "unauthorized", 401)
  end

  @doc """
  Asserts that a response contains a validation error.
  """
  def assert_validation_error(response) do
    assert_error_response(response, "validation_error", 400)
  end

  @doc """
  Asserts that a response contains a not found error.
  """
  def assert_not_found_error(response) do
    assert_error_response(response, "not_found", 404)
  end

  @doc """
  Asserts that a response contains a conflict error.
  """
  def assert_conflict_error(response) do
    assert_error_response(response, "conflict", 409)
  end

  @doc """
  Asserts that a response contains an internal server error.
  """
  def assert_internal_server_error(response) do
    assert_error_response(response, "internal_server_error", 500)
  end

  @doc """
  Asserts that a response contains a forbidden error.
  """
  def assert_forbidden_error(response) do
    assert_error_response(response, "forbidden", 403)
  end

  @doc """
  Asserts that a response contains an error with specific message content.
  Useful when you need to test specific error messages.
  """
  def assert_error_with_message(response, expected_type, expected_status_code, message_contains) do
    assert_error_response(response, expected_type, expected_status_code)
    assert %{"error" => error} = response
    assert String.contains?(error["message"], message_contains)
  end

  @doc """
  Asserts that a response contains an error with specific details.
  """
  def assert_error_with_details(response, expected_type, expected_status_code, expected_details) do
    assert_error_response(response, expected_type, expected_status_code)
    assert %{"error" => error} = response
    assert Map.has_key?(error, "details")

    Enum.each(expected_details, fn {key, value} ->
      assert Map.get(error["details"], key) == value
    end)
  end

  @doc """
  Asserts that a response contains a success response with data.
  """
  def assert_success_response(response, _expected_status_code \\ 200) do
    assert Map.has_key?(response, "data")
    assert response["data"] != nil
  end

  @doc """
  Asserts that a response contains a success response with a specific message.
  """
  def assert_success_with_message(response, expected_message) do
    assert response["message"] == expected_message
  end

  @doc """
  Asserts that a response contains pagination metadata.
  """
  def assert_pagination_metadata(response) do
    assert %{"metadata" => metadata} = response
    assert Map.has_key?(metadata, "total_count")
    assert Map.has_key?(metadata, "page")
    assert Map.has_key?(metadata, "page_size")
    assert Map.has_key?(metadata, "total_pages")
    assert Map.has_key?(metadata, "has_next")
    assert Map.has_key?(metadata, "has_prev")
  end

  @doc """
  Asserts that a response contains a list with the expected count.
  """
  def assert_list_response(response, expected_count) do
    assert %{"data" => data} = response
    assert is_list(data)
    assert length(data) == expected_count
  end

  @doc """
  Asserts that a response contains a single item.
  """
  def assert_single_item_response(response) do
    assert %{"data" => data} = response
    assert is_map(data)
    assert Map.has_key?(data, "id")
  end

  @doc """
  Asserts that a response contains a single item with a specific key.
  """
  def assert_single_response(response, key) do
    assert %{"data" => data} = response
    assert is_map(data)
    assert Map.has_key?(data, key)
  end

  @doc """
  Asserts that a response contains a user object with expected fields.
  """
  def assert_user_response(response) do
    assert %{"data" => %{"user" => user}} = response
    assert Map.has_key?(user, "id")
    assert Map.has_key?(user, "email")
    assert Map.has_key?(user, "full_name")
    assert Map.has_key?(user, "role")
    assert Map.has_key?(user, "status")
  end

  @doc """
  Asserts that a response contains authentication tokens.
  """
  def assert_auth_tokens_response(response) do
    assert %{"data" => data} = response
    assert Map.has_key?(data, "access_token")
    assert Map.has_key?(data, "refresh_token")
    assert is_binary(data["access_token"])
    assert is_binary(data["refresh_token"])
  end

  @doc """
  Asserts that a response contains a bank object with expected fields.
  """
  def assert_bank_response(response) do
    assert %{"data" => bank} = response
    assert Map.has_key?(bank, "id")
    assert Map.has_key?(bank, "name")
    assert Map.has_key?(bank, "country")
    assert Map.has_key?(bank, "code")
  end

  @doc """
  Asserts that a response contains a transaction object with expected fields.
  """
  def assert_transaction_response(response) do
    assert %{"data" => transaction} = response
    assert Map.has_key?(transaction, "id")
    assert Map.has_key?(transaction, "amount")
    assert Map.has_key?(transaction, "description")
    assert Map.has_key?(transaction, "direction")
  end

  @doc """
  Asserts that a response contains a payment object with expected fields.
  """
  def assert_payment_response(response) do
    assert %{"data" => payment} = response
    assert Map.has_key?(payment, "id")
    assert Map.has_key?(payment, "amount")
    assert Map.has_key?(payment, "payment_type")
    assert Map.has_key?(payment, "status")
    assert Map.has_key?(payment, "direction")
  end

  @doc """
  Asserts that a response contains a bad request error.
  """
  def assert_bad_request_error(response) do
    assert_error_response(response, "bad_request", 400)
  end
end

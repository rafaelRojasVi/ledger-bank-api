defmodule LedgerBankApi.Behaviours.ErrorHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias LedgerBankApi.Behaviours.ErrorHandler

  setup :set_mimic_global
  setup :verify_on_exit!

  describe "error_types/0" do
    test "returns standard error types with status codes" do
      types = ErrorHandler.error_types()

      assert types.validation_error == 400
      assert types.not_found == 404
      assert types.unauthorized == 401
      assert types.forbidden == 403
      assert types.conflict == 409
      assert types.unprocessable_entity == 422
      assert types.internal_server_error == 500
      assert types.service_unavailable == 503
    end
  end

  describe "create_error_response/3" do
    test "creates standardized error response" do
      response = ErrorHandler.create_error_response(:not_found, "Resource not found", %{id: "123"})

      assert response.error.type == :not_found
      assert response.error.message == "Resource not found"
      assert response.error.code == 404
      assert response.error.details.id == "123"
      assert Map.has_key?(response.error, :timestamp)
    end

    test "creates error response without details" do
      response = ErrorHandler.create_error_response(:unauthorized, "Access denied")

      assert response.error.type == :unauthorized
      assert response.error.message == "Access denied"
      assert response.error.code == 401
      assert response.error.details == %{}
    end
  end

  describe "handle_common_error/2" do
    test "handles Ecto changeset errors" do
      changeset = Ecto.Changeset.change(%LedgerBankApi.Banking.UserBankAccount{})
      |> Ecto.Changeset.add_error(:email, "is invalid")

      response = ErrorHandler.handle_common_error(changeset, %{context: "user_creation"})

      assert response.error.type == :validation_error
      assert response.error.message == "Validation failed"
      assert response.error.details.errors.email == ["is invalid"]
    end

    test "handles string errors" do
      response = ErrorHandler.handle_common_error({:error, "Something went wrong"}, %{context: "test"})

      assert response.error.type == :unprocessable_entity
      assert response.error.message == "Something went wrong"
    end

    test "handles atom errors" do
      response = ErrorHandler.handle_common_error({:error, :not_found}, %{context: "test"})

      assert response.error.type == :not_found
      assert response.error.message == "Resource not found"
    end

    test "handles unknown errors" do
      response = ErrorHandler.handle_common_error("unknown error", %{context: "test"})

      assert response.error.type == :internal_server_error
      assert response.error.message == "An unexpected error occurred"
    end
  end

  describe "handle_changeset_error/2" do
    test "formats changeset errors correctly" do
      changeset = Ecto.Changeset.change(%LedgerBankApi.Banking.UserBankAccount{})
      |> Ecto.Changeset.add_error(:email, "is invalid")
      |> Ecto.Changeset.add_error(:password, "is too short")

      response = ErrorHandler.handle_changeset_error(changeset, %{context: "user_creation"})

      assert response.error.type == :validation_error
      assert response.error.message == "Validation failed"
      assert response.error.details.errors.email == ["is invalid"]
      assert response.error.details.errors.password == ["is too short"]
    end
  end

  describe "handle_atom_error/2" do
    test "handles :not_found" do
      response = ErrorHandler.handle_atom_error(:not_found, %{context: "test"})

      assert response.error.type == :not_found
      assert response.error.message == "Resource not found"
      assert response.error.code == 404
    end

    test "handles :unauthorized" do
      response = ErrorHandler.handle_atom_error(:unauthorized, %{context: "test"})

      assert response.error.type == :unauthorized
      assert response.error.message == "Unauthorized access"
      assert response.error.code == 401
    end

    test "handles :forbidden" do
      response = ErrorHandler.handle_atom_error(:forbidden, %{context: "test"})

      assert response.error.type == :forbidden
      assert response.error.message == "Access forbidden"
      assert response.error.code == 403
    end

    test "handles :timeout" do
      response = ErrorHandler.handle_atom_error(:timeout, %{context: "test"})

      assert response.error.type == :service_unavailable
      assert response.error.message == "Request timeout"
      assert response.error.code == 503
    end

    test "handles unknown atoms" do
      response = ErrorHandler.handle_atom_error(:unknown_error, %{context: "test"})

      assert response.error.type == :internal_server_error
      assert response.error.message == "Unknown error: unknown_error"
    end
  end

  describe "create_success_response/2" do
    test "creates success response with data" do
      data = %{id: "123", name: "test"}
      response = ErrorHandler.create_success_response(data)

      assert response.data == data
      assert response.success == true
      assert Map.has_key?(response, :timestamp)
    end

    test "creates success response with metadata" do
      data = %{id: "123"}
      metadata = %{count: 1, processed: true}
      response = ErrorHandler.create_success_response(data, metadata)

      assert response.data == data
      assert response.metadata == metadata
    end
  end

  describe "with_error_handling/2" do
    test "handles successful function calls" do
      fun = fn -> {:ok, "success"} end
      result = ErrorHandler.with_error_handling(fun, %{context: "test"})

      assert {:ok, response} = result
      assert response.data == "success"
      assert response.success == true
    end

    test "handles error function calls" do
      fun = fn -> {:error, "something went wrong"} end
      result = ErrorHandler.with_error_handling(fun, %{context: "test"})

      assert {:error, response} = result
      assert response.error.type == :unprocessable_entity
      assert response.error.message == "something went wrong"
    end

    test "handles exceptions" do
      fun = fn -> raise "exception occurred" end
      result = ErrorHandler.with_error_handling(fun, %{context: "test"})

      assert {:error, response} = result
      assert response.error.type == :internal_server_error
      assert response.error.message == "An unexpected error occurred"
    end

    test "handles direct return values" do
      fun = fn -> "direct result" end
      result = ErrorHandler.with_error_handling(fun, %{context: "test"})

      assert {:ok, response} = result
      assert response.data == "direct result"
    end
  end

  describe "behaviour contract" do
    test "module implementing behaviour must have required callbacks" do
      assert function_exported?(ErrorHandler, :handle_common_error, 2)
      assert function_exported?(ErrorHandler, :create_error_response, 3)
      assert function_exported?(ErrorHandler, :log_error, 2)
    end
  end
end

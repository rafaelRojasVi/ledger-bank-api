defmodule LedgerBankApi.Banking.Behaviours.ErrorHandlerTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  import Ecto.Changeset

  defmodule Dummy do
    use Ecto.Schema
    schema "dummy" do
      field :name, :string
    end
  end

  test "handle_changeset_error returns validation error" do
    changeset = cast(%Dummy{}, %{}, [:name]) |> validate_required([:name])
    error = ErrorHandler.handle_common_error(changeset)
    assert error.error.type == :validation_error
    assert error.error.message == "Validation failed"
  end

  test "handle_atom_error returns correct error type" do
    error = ErrorHandler.handle_common_error({:error, :not_found})
    assert error.error.type == :not_found
    error = ErrorHandler.handle_common_error({:error, :unauthorized})
    assert error.error.type == :unauthorized
  end

  test "handle_string_error returns unprocessable_entity" do
    error = ErrorHandler.handle_common_error({:error, "bad input"})
    assert error.error.type == :unprocessable_entity
    assert error.error.message == "bad input"
  end

  test "handle_map_error returns custom error type" do
    error = ErrorHandler.handle_common_error({:error, %{type: :custom, message: "msg"}})
    assert error.error.type == :custom
    assert error.error.message == "msg"
  end

  test "handle_unknown_error returns internal_server_error" do
    error = ErrorHandler.handle_common_error({:error, 123})
    assert error.error.type == :internal_server_error
  end

  test "with_error_handling wraps success and error" do
    assert {:ok, %{data: 1, success: true}} = ErrorHandler.with_error_handling(fn -> {:ok, 1} end)
    assert {:error, %{error: %{type: :internal_server_error}}} = ErrorHandler.with_error_handling(fn -> raise "fail" end)
  end
end

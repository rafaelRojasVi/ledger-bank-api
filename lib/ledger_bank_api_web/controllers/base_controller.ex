defmodule LedgerBankApiWeb.Controllers.BaseController do
  @moduledoc """
  Base controller providing common functionality for all API controllers.

  Implements the "one-thing" error handling pattern by:
  1. Providing consistent error handling helpers
  2. Standardizing response formats
  3. Adding correlation IDs for request tracking
  """

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [assign: 3, put_resp_header: 3, get_req_header: 2]
  alias LedgerBankApiWeb.Adapters.ErrorAdapter
  alias LedgerBankApi.Core.Error

  defmacro __using__(_opts) do
    quote do
      use LedgerBankApiWeb, :controller
      import LedgerBankApiWeb.Controllers.BaseController
      alias LedgerBankApiWeb.Adapters.ErrorAdapter
      alias LedgerBankApi.Core.Error

      # Add correlation ID to all requests
      plug :add_correlation_id
    end
  end

  @doc """
  Plug to add correlation ID to all requests for error tracking.
  """
  def add_correlation_id(conn, _opts) do
    correlation_id = get_correlation_id(conn)
    conn = put_resp_header(conn, "x-correlation-id", correlation_id)
    assign(conn, :correlation_id, correlation_id)
  end

  @doc """
  Handle successful responses with consistent formatting.
  """
  def handle_success(conn, data, metadata \\ %{}) do
    response = %{
      data: data,
      success: true,
      timestamp: DateTime.utc_now(),
      correlation_id: conn.assigns[:correlation_id],
      metadata: metadata
    }

    json(conn, response)
  end

  @doc """
  Handle error responses using the web adapter.
  """
  def handle_error(conn, %Error{} = error) do
    # Add correlation ID to error context if not present
    error_with_correlation = if is_nil(error.correlation_id) do
      %{error | correlation_id: conn.assigns[:correlation_id]}
    else
      error
    end

    ErrorAdapter.handle_error(conn, error_with_correlation)
  end

  @doc """
  Handle generic errors by converting them to canonical Error structs.
  """
  def handle_error(conn, reason, context \\ %{}) do
    context_with_correlation = Map.put(context, :correlation_id, conn.assigns[:correlation_id])
    ErrorAdapter.handle_generic_error(conn, reason, context_with_correlation)
  end

  @doc """
  Handle changeset errors.
  """
  def handle_changeset_error(conn, changeset, context \\ %{}) do
    context_with_correlation = Map.put(context, :correlation_id, conn.assigns[:correlation_id])
    ErrorAdapter.handle_changeset_error(conn, changeset, context_with_correlation)
  end

  @doc """
  Build context map with action and correlation_id for consistent error handling.

  ## Examples

      build_context(conn, :login)
      # => %{action: :login, correlation_id: "abc123"}

      build_context(conn, :update_user, user_id: 123)
      # => %{action: :update_user, user_id: 123, correlation_id: "abc123"}
  """
  def build_context(conn, action, additional_fields \\ %{}) do
    base_context = %{
      action: action,
      correlation_id: conn.assigns[:correlation_id]
    }

    Map.merge(base_context, additional_fields)
  end

  @doc """
  Extract Bearer token from Authorization header.

  ## Examples

      get_auth_token(conn)
      # => {:ok, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
      # => {:error, %Error{}}
  """
  def get_auth_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 ->
        {:ok, token}
      _ ->
        {:error, LedgerBankApi.Core.ErrorHandler.business_error(:invalid_token, %{
          source: "base_controller",
          message: "Missing or invalid authorization header"
        })}
    end
  end

  @doc """
  Handle authentication success responses with consistent structure.

  ## Examples

      handle_auth_success(conn, :login, %{access_token: token, refresh_token: refresh, user: user})
      handle_auth_success(conn, :refresh, %{access_token: token})
      handle_auth_success(conn, :logout, "Logged out successfully")
  """
  def handle_auth_success(conn, action, data) do
    response_data = case action do
      :login ->
        %{
          access_token: data.access_token,
          refresh_token: data.refresh_token,
          user: data.user
        }

      :refresh ->
        %{
          access_token: data.access_token
        }

      :logout ->
        %{
          message: data
        }

      :logout_all ->
        %{
          message: data
        }

      :me ->
        data  # User object directly

      :validate ->
        %{
          valid: true,
          user_id: data.user_id,
          role: data.role,
          expires_at: data.expires_at
        }
    end

    handle_success(conn, response_data)
  end

  @doc """
  Handle standard error patterns for controller actions.

  This helper eliminates the repetitive error handling pattern used across all controllers.

  ## Examples

      # Instead of:
      else
        {:error, %LedgerBankApi.Core.Error{} = error} ->
          handle_error(conn, error)
        {:error, %Ecto.Changeset{} = changeset} ->
          handle_changeset_error(conn, changeset, context)
      end

      # Use:
      else
        handle_standard_errors(conn, context)
      end
  """
  def handle_standard_errors(conn, context) do
    fn
      {:error, %LedgerBankApi.Core.Error{} = error} ->
        handle_error(conn, error)
      {:error, %Ecto.Changeset{} = changeset} ->
        handle_changeset_error(conn, changeset, context)
    end
  end

  @doc """
  Validate parameters and execute service operation with standard error handling.

  This helper eliminates the repetitive validation + service call pattern used across controllers.

  ## Examples

      # Instead of:
      with {:ok, validated_params} <- InputValidator.validate_*(params),
           {:ok, result} <- Service.operation(validated_params) do
        handle_success(conn, result)
      else
        handle_standard_errors(conn, context)
      end

      # Use:
      validate_and_execute(conn, context, InputValidator.validate_*(params), &Service.operation/1, &handle_success(conn, &1))
  """
  def validate_and_execute(conn, context, validation_result, service_operation, success_handler) do
    with {:ok, validated_params} <- validation_result,
         {:ok, result} <- service_operation.(validated_params) do
      success_handler.(result)
    else
      error -> handle_standard_errors(conn, context).(error)
    end
  end

  @doc """
  Validate UUID and get resource with standard error handling.

  This helper eliminates the repetitive UUID validation + resource retrieval pattern used across controllers.

  ## Examples

      # Instead of:
      with {:ok, _validated_id} <- InputValidator.validate_uuid(id, context),
           {:ok, resource} <- Service.get_resource(id) do
        handle_success(conn, resource)
      else
        handle_standard_errors(conn, context)
      end

      # Use:
      validate_uuid_and_get(conn, context, id, &Service.get_resource/1, &handle_success(conn, &1))
  """
  def validate_uuid_and_get(conn, context, id, service_operation, success_handler) do
    with {:ok, _validated_id} <- LedgerBankApiWeb.Validation.InputValidator.validate_uuid(id, context),
         {:ok, resource} <- service_operation.(id) do
      success_handler.(resource)
    else
      error -> handle_standard_errors(conn, context).(error)
    end
  end

  # Note: Parameter extraction functions moved to InputValidator for centralized validation

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_correlation_id(conn) do
    # Try to get from request headers first
    case get_req_header(conn, "x-correlation-id") do
      [correlation_id] when is_binary(correlation_id) -> correlation_id
      _ -> Error.generate_correlation_id()
    end
  end

  # Note: parse_sort_field function moved to InputValidator
end

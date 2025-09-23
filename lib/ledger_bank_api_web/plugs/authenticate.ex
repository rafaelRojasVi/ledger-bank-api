defmodule LedgerBankApiWeb.Plugs.Authenticate do
  @moduledoc """
  Authentication plug that validates JWT access tokens.

  This plug extracts the Bearer token from the Authorization header,
  validates it using AuthService, and adds the current user to conn.assigns.

  ## Usage

      plug LedgerBankApiWeb.Plugs.Authenticate

  ## Conn Assigns

  After successful authentication, the following assigns are added:
  - `:current_user` - The authenticated user struct
  - `:current_token` - The validated JWT token
  - `:current_claims` - The JWT claims

  ## Error Responses

  Returns 401 Unauthorized for:
  - Missing Authorization header
  - Invalid token format
  - Expired tokens
  - Invalid tokens
  """

  import Plug.Conn
  alias LedgerBankApi.Accounts.AuthService
  alias LedgerBankApi.Core.ErrorHandler
  alias LedgerBankApiWeb.Adapters.ErrorAdapter

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- get_auth_header(conn),
         {:ok, _validated_token} <- LedgerBankApiWeb.Validation.InputValidator.validate_access_token(token),
         {:ok, user} <- AuthService.get_user_from_token(token) do
      # Add user and token info to conn assigns
      conn
      |> assign(:current_user, user)
      |> assign(:current_token, token)
      |> assign(:authenticated, true)
    else
      {:error, %LedgerBankApi.Core.Error{} = error} ->
        handle_auth_error(conn, error, %{source: "authenticate_plug"})
      {:error, reason} ->
        handle_auth_error(conn, reason, %{reason: reason, source: "authenticate_plug"})
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_auth_header(conn) do
    case LedgerBankApiWeb.Controllers.BaseController.get_auth_token(conn) do
      {:ok, token} -> {:ok, token}
      {:error, %LedgerBankApi.Core.Error{}} = error -> error
    end
  end

  defp handle_auth_error(conn, reason, context) do
    error = case reason do
      %LedgerBankApi.Core.Error{} = error ->
        # Already a proper Error struct, use as is
        error
      %{reason: :token_expired} ->
        ErrorHandler.business_error(:token_expired, Map.put(context, :message, "Token has expired"))
      %{reason: :invalid_token} ->
        ErrorHandler.business_error(:invalid_token, Map.put(context, :message, "Invalid token"))
      %{reason: :token_revoked} ->
        ErrorHandler.business_error(:token_revoked, Map.put(context, :message, "Token has been revoked"))
      _ ->
        ErrorHandler.business_error(:invalid_token, Map.put(context, :message, "Authentication failed"))
    end

    # Use ErrorAdapter for consistent error handling
    ErrorAdapter.handle_error(conn, error)
    |> halt()
  end
end

defmodule LedgerBankApiWeb.Plugs.Authorize do
  @moduledoc """
  Authorization plug that enforces role-based access control.

  This plug checks if the authenticated user has the required role(s) to access
  the requested resource.

  ## Usage

      # Require admin role
      plug LedgerBankApiWeb.Plugs.Authorize, roles: ["admin"]

      # Require admin or support role
      plug LedgerBankApiWeb.Plugs.Authorize, roles: ["admin", "support"]

      # Require specific role with custom error message
      plug LedgerBankApiWeb.Plugs.Authorize,
        roles: ["admin"],
        error_message: "Admin access required"

  ## Options

  - `:roles` - List of allowed roles (required)
  - `:error_message` - Custom error message (optional)
  - `:allow_self` - Allow users to access their own resources (optional, default: false)

  ## Error Responses

  Returns 403 Forbidden for insufficient permissions.
  """

  import Plug.Conn
  alias LedgerBankApi.Core.ErrorHandler
  alias LedgerBankApiWeb.Adapters.ErrorAdapter

  def init(opts) do
    roles = Keyword.get(opts, :roles, [])
    error_message = Keyword.get(opts, :error_message, "Insufficient permissions")
    allow_self = Keyword.get(opts, :allow_self, false)

    %{
      roles: roles,
      error_message: error_message,
      allow_self: allow_self
    }
  end

  def call(conn, %{roles: required_roles, error_message: error_message, allow_self: allow_self}) do
    current_user = conn.assigns[:current_user]

    if is_nil(current_user) do
      handle_auth_error(conn, "User not authenticated")
    else
      user_role = current_user.role

      # Check if user has required role
      has_role = user_role in required_roles

      # Check if user is accessing their own resource (if allow_self is true)
      is_self_access = if allow_self do
        check_self_access(conn, current_user)
      else
        false
      end

      if has_role or is_self_access do
        conn
      else
        handle_authorization_error(conn, error_message, %{
          user_role: user_role,
          required_roles: required_roles,
          user_id: current_user.id,
          path: conn.request_path
        })
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp check_self_access(conn, current_user) do
    # Check if the user is accessing their own resource
    cond do
      # Profile endpoints - always allow self-access (no :id parameter needed)
      String.starts_with?(conn.request_path, "/api/profile") ->
        true

      # Other endpoints with :id parameter
      is_binary(conn.path_params["id"]) ->
        user_id = conn.path_params["id"]
        user_id == current_user.id

      # No :id parameter and not a profile endpoint
      true ->
        false
    end
  end

  defp handle_auth_error(conn, message) do
    error = ErrorHandler.business_error(:unauthorized_access, %{
      message: message,
      source: "authorize_plug"
    })

    # Use ErrorAdapter for consistent error handling
    ErrorAdapter.handle_error(conn, error)
    |> halt()
  end

  defp handle_authorization_error(conn, message, context) do
    error = ErrorHandler.business_error(:insufficient_permissions, Map.put(context, :message, message))

    # Use ErrorAdapter for consistent error handling
    ErrorAdapter.handle_error(conn, error)
    |> halt()
  end
end

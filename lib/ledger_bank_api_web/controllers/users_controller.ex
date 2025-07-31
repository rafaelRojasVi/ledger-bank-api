defmodule LedgerBankApiWeb.UsersController do
  @moduledoc """
  Optimized users controller using base controller patterns.
  Provides user management operations with admin-only access.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController, except: [action: 2]
  require LedgerBankApi.Helpers.AuthorizationHelpers

  alias LedgerBankApi.Users.Context
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  alias LedgerBankApi.Helpers.AuthorizationHelpers

  # Standard CRUD operations for users (admin only)
  crud_operations(
    Context,
    LedgerBankApi.Users.User,
    "user",
    authorization: :admin_or_owner
  )

  # Custom admin actions
  def suspend(conn, %{"id" => user_id}) do
    current_user_id = conn.assigns.current_user_id
    context = %{action: :suspend, user_id: current_user_id, target_user_id: user_id}

    # Require admin role
    current_user = LedgerBankApi.Users.Context.get!(current_user_id)
    AuthorizationHelpers.require_role!(current_user, "admin")

    case ErrorHandler.with_error_handling(fn ->
      user = Context.get!(user_id)
      Context.suspend_user(user)
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> json(response.data)
      {:error, error_response} ->
        response = ErrorHandler.handle_common_error(error_response, context)
        conn |> put_status(400) |> json(response)
    end
  end

  def activate(conn, %{"id" => user_id}) do
    current_user_id = conn.assigns.current_user_id
    context = %{action: :activate, user_id: current_user_id, target_user_id: user_id}

    # Require admin role
    current_user = LedgerBankApi.Users.Context.get!(current_user_id)
    AuthorizationHelpers.require_role!(current_user, "admin")

    case ErrorHandler.with_error_handling(fn ->
      user = Context.get!(user_id)
      Context.activate_user(user)
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> json(response.data)
      {:error, error_response} ->
        response = ErrorHandler.handle_common_error(error_response, context)
        conn |> put_status(400) |> json(response)
    end
  end

  def list_by_role(conn, %{"role" => role}) do
    current_user_id = conn.assigns.current_user_id
    context = %{action: :list_by_role, user_id: current_user_id, role: role}

    # Require admin role
    current_user = LedgerBankApi.Users.Context.get!(current_user_id)
    AuthorizationHelpers.require_role!(current_user, "admin")

    case ErrorHandler.with_error_handling(fn ->
      Context.list_users_by_role(role)
    end, context) do
      {:ok, response} ->
        conn
        |> put_status(200)
        |> json(response.data)
      {:error, error_response} ->
        response = ErrorHandler.handle_common_error(error_response, context)
        conn |> put_status(400) |> json(response)
    end
  end


end

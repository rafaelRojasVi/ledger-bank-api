defmodule LedgerBankApiWeb.UsersController do
  @moduledoc """
  Optimized users controller using base controller patterns.
  Provides user management operations with admin-only access.
  """

  use LedgerBankApiWeb, :controller

  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  # Custom admin actions
  def suspend(conn, %{"id" => user_id}) do
    current_user_id = conn.assigns.current_user_id
    context = %{action: :suspend, user_id: current_user_id, target_user_id: user_id}

    # Require admin role
    {:ok, current_user} = LedgerBankApi.Users.get_user(current_user_id)
    if current_user.role != "admin", do: raise "Unauthorized: Admin role required"

    case ErrorHandler.with_error_handling(fn ->
      {:ok, user} = LedgerBankApi.Users.get_user(user_id)
      LedgerBankApi.Users.update_user(user, %{status: "SUSPENDED"})
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
    {:ok, current_user} = LedgerBankApi.Users.get_user(current_user_id)
    if current_user.role != "admin", do: raise "Unauthorized: Admin role required"

    case ErrorHandler.with_error_handling(fn ->
      {:ok, user} = LedgerBankApi.Users.get_user(user_id)
      LedgerBankApi.Users.update_user(user, %{status: "ACTIVE"})
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
    {:ok, current_user} = LedgerBankApi.Users.get_user(current_user_id)
    if current_user.role != "admin", do: raise "Unauthorized: Admin role required"

    case ErrorHandler.with_error_handling(fn ->
      LedgerBankApi.Users.list_users_by_role(role)
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

defmodule LedgerBankApiWeb.UsersControllerV2 do
  @moduledoc """
  Optimized users controller using base controller patterns.
  Provides user management operations with admin-only access.
  """

  use LedgerBankApiWeb, :controller
  import LedgerBankApiWeb.BaseController
  import LedgerBankApiWeb.JSON.BaseJSON

  alias LedgerBankApi.Users.Context

  # Standard CRUD operations for users (admin only)
  crud_operations(
    Context,
    LedgerBankApi.Users.User,
    "user",
    authorization: :admin_or_owner
  )

  # Custom admin actions
  action :suspend do
    user = Context.get_user!(params["id"])
    Context.suspend_user(user)
  end

  action :activate do
    user = Context.get_user!(params["id"])
    Context.activate_user(user)
  end

  action :list_by_role do
    Context.list_users_by_role(params["role"])
  end

  # Override index to require admin role
  def index(conn, params) do
    current_user = conn.assigns.current_user
    context = %{action: :list_users, user_id: current_user.id}

    # Require admin role
    AuthorizationHelpers.require_role!(current_user, "admin")

    case ErrorHandler.with_error_handling(fn ->
      Context.list()
    end, context) do
      {:ok, response} ->
        render(conn, :index, %{user: response.data})
      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  # Override show to allow admin or self-access
  def show(conn, %{"id" => user_id}) do
    current_user = conn.assigns.current_user
    context = %{action: :get_user, user_id: current_user.id, target_user_id: user_id}

    # Require admin role or be the same user
    unless current_user.id == user_id do
      AuthorizationHelpers.require_role!(current_user, "admin")
    end

    case ErrorHandler.with_error_handling(fn ->
      Context.get_user!(user_id)
    end, context) do
      {:ok, response} ->
        render(conn, :show, %{user: response.data})
      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  # Override update to allow admin or self-access
  def update(conn, %{"id" => user_id} = params) do
    current_user = conn.assigns.current_user
    context = %{action: :update_user, user_id: current_user.id, target_user_id: user_id}

    # Require admin role or be the same user
    unless current_user.id == user_id do
      AuthorizationHelpers.require_role!(current_user, "admin")
    end

    user = Context.get_user!(user_id)

    case ErrorHandler.with_error_handling(fn ->
      Context.update_user(user, params["user"] || %{})
    end, context) do
      {:ok, response} ->
        render(conn, :show, %{user: response.data})
      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end

  # Override delete to require admin role
  def delete(conn, %{"id" => user_id}) do
    current_user = conn.assigns.current_user
    context = %{action: :delete_user, user_id: current_user.id, target_user_id: user_id}

    # Require admin role
    AuthorizationHelpers.require_role!(current_user, "admin")

    user = Context.get_user!(user_id)

    case ErrorHandler.with_error_handling(fn ->
      Context.delete_user(user)
    end, context) do
      {:ok, _response} ->
        conn
        |> put_status(204)
        |> send_resp(:no_content, "")
      {:error, error_response} ->
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
    end
  end
end

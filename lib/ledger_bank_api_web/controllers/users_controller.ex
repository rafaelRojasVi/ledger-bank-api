defmodule LedgerBankApiWeb.Controllers.UsersController do
  @moduledoc """
  Users controller handling user CRUD operations.

  Uses the "one-thing" error handling pattern with canonical Error structs.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  alias LedgerBankApi.Accounts.UserService

  @doc """
  List users with optional filtering and pagination.

  GET /api/users?page=1&page_size=20&sort=email:asc&status=ACTIVE
  """
  def index(conn, params) do
    pagination = extract_pagination_params(params)
    sort = extract_sort_params(params)
    filters = extract_filter_params(params)

    opts = [
      pagination: pagination,
      sort: sort,
      filters: filters
    ]

    users = UserService.list_users(opts)

    # Get total count for pagination metadata
    total_count = UserService.get_user_statistics()
    |> elem(1)
    |> Map.get(:total_users)

    metadata = %{
      pagination: %{
        page: pagination.page,
        page_size: pagination.page_size,
        total_count: total_count,
        total_pages: ceil(total_count / pagination.page_size)
      }
    }

    handle_success(conn, users, metadata)
  end

  @doc """
  Get a specific user by ID.

  GET /api/users/:id
  """
  def show(conn, %{"id" => id}) do
    case UserService.get_user(id) do
      {:ok, user} ->
        handle_success(conn, user)

      {:error, reason} ->
        handle_error(conn, reason, %{action: :show, user_id: id})
    end
  end

  @doc """
  Create a new user.

  POST /api/users
  Body: %{
    "email" => "user@example.com",
    "full_name" => "John Doe",
    "password" => "password123",
    "password_confirmation" => "password123",
    "role" => "user"
  }
  """
  def create(conn, params) do
    case UserService.create_user(params) do
      {:ok, user} ->
        # Remove sensitive fields from response
        user_data = %{
          id: user.id,
          email: user.email,
          full_name: user.full_name,
          role: user.role,
          status: user.status,
          active: user.active,
          verified: user.verified,
          inserted_at: user.inserted_at,
          updated_at: user.updated_at
        }

        conn
        |> put_status(:created)
        |> handle_success(user_data)

      {:error, %Ecto.Changeset{} = changeset} ->
        handle_changeset_error(conn, changeset, %{action: :create})

      {:error, reason} ->
        handle_error(conn, reason, %{action: :create})
    end
  end

  @doc """
  Update a user.

  PUT /api/users/:id
  Body: %{
    "full_name" => "John Smith",
    "status" => "ACTIVE"
  }
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, user} <- UserService.get_user(id) do
      update_params = Map.delete(params, "id")

      case UserService.update_user(user, update_params) do
        {:ok, updated_user} ->
          # Remove sensitive fields from response
          user_data = %{
            id: updated_user.id,
            email: updated_user.email,
            full_name: updated_user.full_name,
            role: updated_user.role,
            status: updated_user.status,
            active: updated_user.active,
            verified: updated_user.verified,
            inserted_at: updated_user.inserted_at,
            updated_at: updated_user.updated_at
          }

          handle_success(conn, user_data)

        {:error, %Ecto.Changeset{} = changeset} ->
          handle_changeset_error(conn, changeset, %{action: :update, user_id: id})

        {:error, reason} ->
          handle_error(conn, reason, %{action: :update, user_id: id})
      end
    end
  end

  @doc """
  Delete a user.

  DELETE /api/users/:id
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- UserService.get_user(id) do
      case UserService.delete_user(user) do
        {:ok, _deleted_user} ->
          handle_success(conn, %{message: "User deleted successfully"})

        {:error, %Ecto.Changeset{} = changeset} ->
          handle_changeset_error(conn, changeset, %{action: :delete, user_id: id})

        {:error, reason} ->
          handle_error(conn, reason, %{action: :delete, user_id: id})
      end
    end
  end

  @doc """
  Get user statistics.

  GET /api/users/stats
  """
  def stats(conn, _params) do
    {:ok, stats} = UserService.get_user_statistics()
    handle_success(conn, stats)
  end
end

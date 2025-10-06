defmodule LedgerBankApiWeb.Controllers.UsersController do
  @moduledoc """
  Users controller handling user CRUD operations and profile management.

  Uses action fallback for centralized error handling.
  Implements proper input validation and authorization.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  alias LedgerBankApi.Accounts.UserService
  alias LedgerBankApi.Core.ErrorHandler
  alias LedgerBankApiWeb.Validation.InputValidator

  action_fallback LedgerBankApiWeb.FallbackController

  @doc """
  List users with optional filtering and pagination.

  GET /api/users?page=1&page_size=20&sort=email:asc&status=ACTIVE
  """
  def index(conn, params) do
    with {:ok, pagination} <- InputValidator.extract_pagination_params(params),
         {:ok, sort} <- InputValidator.extract_sort_params(params),
         {:ok, filters} <- InputValidator.extract_filter_params(params) do

      opts = [
        pagination: pagination,
        sort: sort,
        filters: filters
      ]

      users = UserService.list_users(opts)

      # Get total count for pagination metadata
      {:ok, stats} = UserService.get_user_statistics()
      total_count = Map.get(stats, :total_users, 0)

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
  end

  @doc """
  List users with keyset pagination for better performance.

  GET /api/users/keyset?limit=20&cursor={"inserted_at":"2024-01-01T00:00:00Z","id":"user-id"}&status=ACTIVE
  """
  def index_keyset(conn, params) do
    with {:ok, filters} <- InputValidator.extract_filter_params(params) do
      # Parse cursor from query params
      cursor = case params["cursor"] do
        nil -> nil
        cursor_string when is_binary(cursor_string) ->
          case Jason.decode(cursor_string) do
            {:ok, %{"inserted_at" => inserted_at, "id" => id}} ->
              case DateTime.from_iso8601(inserted_at) do
                {:ok, dt, _} -> %{inserted_at: dt, id: id}
                _ -> nil
              end
            _ -> nil
          end
        _ -> nil
      end

      # Parse limit
      limit = case Integer.parse(params["limit"] || "20") do
        {limit_num, ""} when limit_num >= 1 and limit_num <= 100 -> limit_num
        {limit_num, ""} when limit_num > 100 -> 100
        _ -> 20
      end

      opts = [
        cursor: cursor,
        limit: limit,
        filters: filters
      ]

      result = UserService.list_users_keyset(opts)

      metadata = %{
        pagination: %{
          type: "keyset",
          limit: limit,
          has_more: result.has_more,
          next_cursor: result.next_cursor
        }
      }

      handle_success(conn, result.data, metadata)
    end
  end

  @doc """
  Get a specific user by ID.

  GET /api/users/:id
  """
  def show(conn, %{"id" => id}) do
    with {:ok, _validated_id} <- InputValidator.validate_user_id(id),
         {:ok, user} <- UserService.get_user(id) do
      handle_success(conn, user)
    end
  end

  @doc """
  Create a new user (public registration).

  POST /api/users
  Body: %{
    "email" => "user@example.com",
    "full_name" => "John Doe",
    "password" => "password123",
    "password_confirmation" => "password123"
  }

  SECURITY NOTE: Role is always forced to "user" for public registration.
  The "role" parameter is ignored to prevent unauthorized admin creation.
  """
  def create(conn, params) do
    with {:ok, validated_params} <- InputValidator.validate_user_creation(params),
         {:ok, user} <- UserService.create_user_with_normalization(validated_params) do
      conn
      |> put_status(:created)
      |> handle_success(user)
    end
  end

  @doc """
  Create a new user as admin (allows role selection).

  POST /api/users/admin
  Body: %{
    "email" => "admin@example.com",
    "full_name" => "Admin User",
    "password" => "password123456789",
    "password_confirmation" => "password123456789",
    "role" => "admin"
  }

  SECURITY NOTE: This endpoint is admin-only and allows creating users with any role.
  """
  def create_as_admin(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, validated_params} <- InputValidator.validate_admin_user_creation(params),
         {:ok, user} <- UserService.create_user_as_admin(validated_params, current_user) do
      conn
      |> put_status(:created)
      |> handle_success(user)
    end
  end

  @doc """
  Update a user (admin only).

  PUT /api/users/:id
  Body: %{
    "full_name" => "John Smith",
    "status" => "ACTIVE"
  }
  """
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, _validated_id} <- InputValidator.validate_user_id(id),
         {:ok, user} <- UserService.get_user(id),
         {:ok, validated_params} <- InputValidator.validate_user_update(params),
         {:ok, updated_user} <- UserService.update_user_with_normalization_and_policy(user, validated_params, current_user) do
      handle_success(conn, updated_user)
    end
  end

  @doc """
  Delete a user (admin only).

  DELETE /api/users/:id
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, _validated_id} <- InputValidator.validate_user_id(id),
         {:ok, user} <- UserService.get_user(id),
         {:ok, _} <- UserService.delete_user(user) do
      handle_success(conn, %{message: "User deleted successfully"})
    end
  end

  @doc """
  Get user statistics (admin only).

  GET /api/users/stats
  """
  def stats(conn, _params) do
    {:ok, stats} = UserService.get_user_statistics()
    handle_success(conn, stats)
  end

  # ============================================================================
  # PROFILE MANAGEMENT ENDPOINTS
  # ============================================================================

  @doc """
  Get current user's profile.

  GET /api/profile
  """
  def show_profile(conn, _params) do
    current_user = conn.assigns[:current_user]

    if current_user do
      handle_success(conn, current_user)
    else
      {:error, ErrorHandler.business_error(:user_not_found, %{message: "User not found"})}
    end
  end

  @doc """
  Update current user's profile.

  PUT /api/profile
  Body: %{
    "full_name" => "John Smith"
  }
  """
  def update_profile(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, validated_params} <- InputValidator.validate_user_update(params),
         {:ok, updated_user} <- UserService.update_user_with_normalization_and_policy(current_user, validated_params, current_user) do
      handle_success(conn, updated_user)
    end
  end

  @doc """
  Update current user's password.

  PUT /api/profile/password
  Body: %{
    "current_password" => "oldpassword",
    "new_password" => "newpassword123",
    "password_confirmation" => "newpassword123"
  }
  """
  def update_password(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, validated_params} <- InputValidator.validate_password_change(params, current_user.role),
         {:ok, _} <- UserService.update_user_password_with_policy(current_user, validated_params) do
      handle_success(conn, %{message: "Password updated successfully"})
    end
  end
end

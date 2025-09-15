defmodule LedgerBankApi.Users do
  @moduledoc """
  Consolidated user management business logic.
  Combines functionality from users/context.ex and authorization_helpers.ex.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  import LedgerBankApi.Database.Macros

  # Schemas
  alias LedgerBankApi.Users.User
  alias LedgerBankApi.Users.RefreshToken

  # ============================================================================
  # USER MANAGEMENT
  # ============================================================================

  @doc """
  List all users with optional filters.
  """
  def list_users(opts \\ []) do
    with_error_handling(:list_users, %{opts: opts}, do:
      User
      |> apply_user_filters(opts[:filters])
      |> apply_user_sorting(opts[:sort])
      |> apply_user_pagination(opts[:pagination])
      |> Repo.all()
    )
  end

  @doc """
  Get a user by ID.
  """
  def get_user(id) do
    with_error_handling(:get_user, %{id: id}, do:
      case Repo.get(User, id) do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    )
  end

  @doc """
  Get a user by email.
  """
  def get_user_by_email(email) do
    with_error_handling(:get_user_by_email, %{email: email}, do:
      case Repo.get_by(User, email: email) do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    )
  end

  @doc """
  Create a new user.
  """
  def create_user(attrs) do
    with_error_handling(:create_user, %{attrs: attrs}, do:
      # Check if email already exists
      case get_user_by_email(attrs[:email]) do
        {:ok, _user} ->
          {:error, ErrorHandler.business_error(:email_already_exists, %{email: attrs[:email]})}
        {:error, :not_found} ->
          %User{}
          |> User.changeset(attrs)
          |> Repo.insert()
        error ->
          error
      end
    )
  end

  @doc """
  Update a user.
  """
  def update_user(user, attrs) do
    with_error_handling(:update_user, %{user_id: user.id, attrs: attrs}, do:
      user
      |> User.changeset(attrs)
      |> Repo.update()
    )
  end

  @doc """
  Delete a user.
  """
  def delete_user(user) do
    with_error_handling(:delete_user, %{user_id: user.id}, do:
      Repo.delete(user)
    )
  end

  @doc """
  List active users.
  """
  def list_active_users do
    with_error_handling(:list_active_users, %{}, do:
      User |> where(status: "ACTIVE") |> Repo.all()
    )
  end

  @doc """
  List suspended users.
  """
  def list_suspended_users do
    with_error_handling(:list_suspended_users, %{}, do:
      User |> where(status: "SUSPENDED") |> Repo.all()
    )
  end

  @doc """
  List users by role.
  """
  def list_users_by_role(role) do
    with_error_handling(:list_users_by_role, %{role: role}, do:
      User |> where([u], u.role == ^role) |> Repo.all()
    )
  end

  @doc """
  Get user with preloads.
  """
  def get_user_with_preloads(id, preloads) do
    with_error_handling(:get_user_with_preloads, %{id: id, preloads: preloads}, do:
      User
      |> Repo.get!(id)
      |> Repo.preload(preloads)
    )
  end

  @doc """
  Update user status.
  """
  def update_user_status(user, status) do
    with_error_handling(:update_user_status, %{user_id: user.id, status: status}, do:
      user
      |> Ecto.Changeset.change(%{status: status})
      |> Repo.update()
    )
  end

  @doc """
  Update user role.
  """
  def update_user_role(user, role) do
    with_error_handling(:update_user_role, %{user_id: user.id, role: role}, do:
      user
      |> Ecto.Changeset.change(%{role: role})
      |> Repo.update()
    )
  end

  @doc """
  Check if user exists by email.
  """
  def user_exists_by_email?(email) do
    with_error_handling(:user_exists_by_email, %{email: email}, do:
      case Repo.get_by(User, email: email) do
        nil -> false
        _ -> true
      end
    )
  end

  @doc """
  Count users by status.
  """
  def count_users_by_status(status) do
    with_error_handling(:count_users_by_status, %{status: status}, do:
      Repo.aggregate(
        from(u in User, where: u.status == ^status),
        :count
      )
    )
  end

  @doc """
  Count users by role.
  """
  def count_users_by_role(role) do
    with_error_handling(:count_users_by_role, %{role: role}, do:
      Repo.aggregate(
        from(u in User, where: u.role == ^role),
        :count
      )
    )
  end

  # ============================================================================
  # REFRESH TOKEN MANAGEMENT
  # ============================================================================

  @doc """
  Create a refresh token.
  """
  def create_refresh_token(attrs) do
    with_error_handling(:create_refresh_token, %{attrs: attrs}, do:
      %RefreshToken{}
      |> RefreshToken.changeset(attrs)
      |> Repo.insert()
    )
  end

  @doc """
  Get a refresh token by JTI.
  """
  def get_refresh_token(jti) do
    with_error_handling(:get_refresh_token, %{jti: jti}, do:
      case Repo.get_by(RefreshToken, jti: jti) do
        nil -> {:error, :not_found}
        refresh_token -> {:ok, refresh_token}
      end
    )
  end

  @doc """
  Revoke a refresh token.
  """
  def revoke_refresh_token(jti) do
    with_error_handling(:revoke_refresh_token, %{jti: jti}, do:
      case get_refresh_token(jti) do
        {:ok, refresh_token} ->
          refresh_token
          |> RefreshToken.changeset(%{revoked_at: DateTime.utc_now()})
          |> Repo.update()
        {:error, :not_found} ->
          {:error, ErrorHandler.business_error(:token_not_found, %{jti: jti})}
        error ->
          error
      end
    )
  end

  @doc """
  Revoke all refresh tokens for a user.
  """
  def revoke_all_refresh_tokens(user_id) do
    with_error_handling(:revoke_all_refresh_tokens, %{user_id: user_id}, do:
      RefreshToken
      |> where([rt], rt.user_id == ^user_id and is_nil(rt.revoked_at))
      |> Repo.update_all(set: [revoked_at: DateTime.utc_now()])
      |> then(fn {count, _} -> {:ok, count} end)
    )
  end

  # ============================================================================
  # AUTHORIZATION HELPERS
  # ============================================================================

  @doc """
  Check if user has admin role.
  """
  def is_admin?(user) do
    user.role == "admin"
  end

  @doc """
  Check if user has support role.
  """
  def is_support?(user) do
    user.role == "support"
  end

  @doc """
  Check if user has user role.
  """
  def is_user?(user) do
    user.role == "user"
  end

  @doc """
  Check if user can access resource.
  """
  def can_access_resource?(user, resource_user_id) do
    is_admin?(user) || user.id == resource_user_id
  end

  @doc """
  Check if user can modify resource.
  """
  def can_modify_resource?(user, resource_user_id) do
    is_admin?(user) || user.id == resource_user_id
  end

  @doc """
  Check if user can delete resource.
  """
  def can_delete_resource?(user, resource_user_id) do
    is_admin?(user) || user.id == resource_user_id
  end

  @doc """
  Check if user can view all resources.
  """
  def can_view_all_resources?(user) do
    is_admin?(user) || is_support?(user)
  end

  @doc """
  Check if user can modify all resources.
  """
  def can_modify_all_resources?(user) do
    is_admin?(user)
  end

  @doc """
  Check if user can delete all resources.
  """
  def can_delete_all_resources?(user) do
    is_admin?(user)
  end

  # ============================================================================
  # FILTER FUNCTIONS
  # ============================================================================

  defp apply_user_filters(query, nil), do: query
  defp apply_user_filters(query, []), do: query
  defp apply_user_filters(query, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn {field, value}, acc ->
      case field do
        :status when is_binary(value) ->
          where(acc, [u], u.status == ^value)
        :role when is_binary(value) ->
          where(acc, [u], u.role == ^value)
        :active when is_boolean(value) ->
          where(acc, [u], u.active == ^value)
        :verified when is_boolean(value) ->
          where(acc, [u], u.verified == ^value)
        :suspended when is_boolean(value) ->
          where(acc, [u], u.suspended == ^value)
        :deleted when is_boolean(value) ->
          where(acc, [u], u.deleted == ^value)
        :created_at_start when is_binary(value) ->
          where(acc, [u], u.inserted_at >= ^value)
        :created_at_end when is_binary(value) ->
          where(acc, [u], u.inserted_at <= ^value)
        :updated_at_start when is_binary(value) ->
          where(acc, [u], u.updated_at >= ^value)
        :updated_at_end when is_binary(value) ->
          where(acc, [u], u.updated_at <= ^value)
        _ -> acc
      end
    end)
  end

  # ============================================================================
  # SORT FUNCTIONS
  # ============================================================================

  defp apply_user_sorting(query, nil), do: query
  defp apply_user_sorting(query, []), do: query
  defp apply_user_sorting(query, sort) when is_list(sort) do
    Enum.reduce(sort, query, fn {field, direction}, acc ->
      case direction do
        :asc -> order_by(acc, [u], asc: field(u, ^field))
        :desc -> order_by(acc, [u], desc: field(u, ^field))
        _ -> acc
      end
    end)
  end

  # ============================================================================
  # PAGINATION FUNCTIONS
  # ============================================================================

  defp apply_user_pagination(query, nil), do: query
  defp apply_user_pagination(query, %{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size
    query
    |> limit(^page_size)
    |> offset(^offset)
  end

  # ============================================================================
  # MACRO GENERATED CRUD OPERATIONS
  # ============================================================================

  # Note: CRUD operations are already implemented above for User and RefreshToken
  # The macro is not used here to avoid conflicts with existing implementations
end

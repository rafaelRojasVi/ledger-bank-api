defmodule LedgerBankApi.Accounts.UserService do
  @moduledoc """
  User business logic service.

  Handles all user-related business operations including CRUD operations,
  authentication, and user management.
  """

  @behaviour LedgerBankApi.Core.ServiceBehavior

  import Ecto.Query, warn: false
  require LedgerBankApi.Core.ServiceBehavior
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Core.{ErrorHandler, ServiceBehavior, Validator}
  alias LedgerBankApi.Accounts.Schemas.{User, RefreshToken}

  # ============================================================================
  # SERVICE BEHAVIOR IMPLEMENTATION
  # ============================================================================

  @impl LedgerBankApi.Core.ServiceBehavior
  def service_name, do: "user_service"

  # ============================================================================
  # USER CRUD OPERATIONS
  # ============================================================================

  @doc """
  Get a user by ID.
  """
  def get_user(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_user, %{user_id: id})

    # Validate user ID format before querying
    case Validator.validate_uuid(id) do
      :ok ->
        ServiceBehavior.get_operation(User, id, :user_not_found, context)
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, context)}
    end
  end

  @doc """
  Get a user by email.
  """
  def get_user_by_email(email) do
    context = ServiceBehavior.build_context(__MODULE__, :get_user_by_email, %{email: email})

    ServiceBehavior.get_by_operation(User, [email: email], :user_not_found, context)
  end

  @doc """
  List users with optional filters.
  """
  def list_users(opts \\ []) do
    User
    |> apply_user_filters(opts[:filters])
    |> apply_user_sorting(opts[:sort])
    |> apply_user_pagination(opts[:pagination])
    |> Repo.all()
  end

  @doc """
  Create a new user.
  """
  def create_user(attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :create_user, %{email: attrs[:email]})

    ServiceBehavior.with_error_handling(context, fn ->
      # Check if email already exists
      case get_user_by_email(attrs[:email]) do
        {:ok, _user} ->
          {:error, ErrorHandler.business_error(:email_already_exists, context)}
        {:error, %LedgerBankApi.Core.Error{} = _error} ->
          # User not found, safe to create
          ServiceBehavior.create_operation(&User.changeset(%User{}, &1), attrs, context)
      end
    end)
  end

  @doc """
  Update a user.
  """
  def update_user(user, attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user, %{user_id: user.id})

    ServiceBehavior.update_operation(&User.update_changeset/2, user, attrs, context)
  end

  @doc """
  Delete a user.
  """
  def delete_user(user) do
    context = ServiceBehavior.build_context(__MODULE__, :delete_user, %{user_id: user.id})

    ServiceBehavior.delete_operation(user, context)
  end

  @doc """
  Update user password.
  """
  def update_user_password(user, attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user_password, %{user_id: user.id})

    ServiceBehavior.update_operation(&User.password_changeset/2, user, attrs, context)
  end

  # ============================================================================
  # REFRESH TOKEN MANAGEMENT
  # ============================================================================

  @doc """
  Create a refresh token.
  """
  def create_refresh_token(attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :create_refresh_token, %{user_id: attrs[:user_id]})

    # Validate user_id, jti, and expires_at format before creating
    with :ok <- Validator.validate_uuid(attrs[:user_id]),
         :ok <- Validator.validate_uuid(attrs[:jti]),
         :ok <- Validator.validate_future_datetime(attrs[:expires_at]) do
      ServiceBehavior.create_operation(&RefreshToken.changeset(%RefreshToken{}, &1), attrs, context)
    else
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, context)}
    end
  end

  @doc """
  Get a refresh token by JTI.
  """
  def get_refresh_token(jti) do
    context = ServiceBehavior.build_context(__MODULE__, :get_refresh_token, %{jti: jti})

    # Validate JTI format before querying
    case Validator.validate_uuid(jti) do
      :ok ->
        ServiceBehavior.get_by_operation(RefreshToken, [jti: jti], :token_not_found, context)
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, context)}
    end
  end

  @doc """
  Revoke a refresh token.
  """
  def revoke_refresh_token(jti) do
    context = ServiceBehavior.build_context(__MODULE__, :revoke_refresh_token, %{jti: jti})

    # Validate JTI format before proceeding
    case Validator.validate_uuid(jti) do
      :ok ->
        case get_refresh_token(jti) do
          {:ok, refresh_token} ->
            # Check if token is already revoked
            if RefreshToken.revoked?(refresh_token) do
              {:error, ErrorHandler.business_error(:token_not_found, context)}
            else
              case refresh_token
                   |> RefreshToken.changeset(%{revoked_at: DateTime.utc_now()})
                   |> Repo.update() do
                {:ok, updated_token} -> {:ok, updated_token}
                {:error, changeset} ->
                  {:error, ErrorHandler.handle_changeset_error(changeset, %{jti: jti, source: "user_service"})}
              end
            end
          {:error, %LedgerBankApi.Core.Error{} = error} ->
            {:error, error}
        end
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, context)}
    end
  end

  @doc """
  Revoke all refresh tokens for a user.
  """
  def revoke_all_refresh_tokens(user_id) do
    context = ServiceBehavior.build_context(__MODULE__, :revoke_all_refresh_tokens, %{user_id: user_id})

    # Validate user_id format before querying
    case Validator.validate_uuid(user_id) do
      :ok ->
        {count, _} = Repo.update_all(
          from(t in RefreshToken, where: t.user_id == ^user_id and is_nil(t.revoked_at)),
          set: [revoked_at: DateTime.utc_now()]
        )
        {:ok, count}
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, context)}
    end
  end

  @doc """
  List active refresh tokens for a user.
  """
  def list_active_refresh_tokens(user_id) do
    RefreshToken
    |> where([t], t.user_id == ^user_id and is_nil(t.revoked_at) and t.expires_at > ^DateTime.utc_now())
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Clean up expired refresh tokens.
  """
  def cleanup_expired_refresh_tokens do
    Repo.delete_all(
      from(t in RefreshToken, where: t.expires_at <= ^DateTime.utc_now())
    )
    |> then(fn {count, _} -> {:ok, count} end)
  end

  # ============================================================================
  # USER AUTHENTICATION HELPERS
  # ============================================================================

  @doc """
  Authenticate user with email and password.
  """
  def authenticate_user(email, password) do
    context = ServiceBehavior.build_context(__MODULE__, :authenticate_user, %{email: email})

    # Validate email and password format before querying
    with :ok <- Validator.validate_email_secure(email),
         :ok <- Validator.validate_password(password) do
      case get_user_by_email(email) do
        {:ok, user} ->
          # Check if user is active before verifying password
          if is_user_active?(user) do
            if Argon2.verify_pass(password, user.password_hash) do
              {:ok, user}
            else
              {:error, ErrorHandler.business_error(:invalid_credentials, %{email: email, source: "user_service"})}
            end
          else
            {:error, ErrorHandler.business_error(:account_inactive, %{email: email, source: "user_service"})}
          end
        {:error, %LedgerBankApi.Core.Error{} = error} ->
          {:error, error}
      end
    else
      {:error, reason} ->
        {:error, ErrorHandler.business_error(reason, context)}
    end
  end

  @doc """
  Check if user is active.
  """
  def is_user_active?(%User{status: "ACTIVE", active: true, suspended: false, deleted: false}), do: true
  def is_user_active?(_), do: false

  @doc """
  Check if user has admin privileges.
  """
  def is_admin?(%User{role: "admin"}), do: true
  def is_admin?(_), do: false

  @doc """
  Check if user has support privileges.
  """
  def is_support?(%User{role: role}), do: role in ["admin", "support"]
  def is_support?(_), do: false

  @doc """
  Get user statistics.
  """
  def get_user_statistics do
    total_users = Repo.aggregate(User, :count)
    active_users = Repo.aggregate(from(u in User, where: u.status == "ACTIVE"), :count)
    admin_users = Repo.aggregate(from(u in User, where: u.role == "admin"), :count)

    {:ok, %{
      total_users: total_users,
      active_users: active_users,
      admin_users: admin_users,
      suspended_users: total_users - active_users
    }}
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
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
        _ ->
          acc
      end
    end)
  end

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

  defp apply_user_pagination(query, nil), do: query
  defp apply_user_pagination(query, %{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size
    query
    |> limit(^page_size)
    |> offset(^offset)
  end
end

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
  alias LedgerBankApi.Accounts.Policy
  alias LedgerBankApi.Accounts.Normalize
  alias LedgerBankApi.Financial.Workers.{BankSyncWorker, PaymentWorker}
  alias LedgerBankApiWeb.Logger, as: AppLogger
  alias LedgerBankApi.Core.Cache

  # ============================================================================
  # SERVICE BEHAVIOR IMPLEMENTATION
  # ============================================================================

  @impl LedgerBankApi.Core.ServiceBehavior
  def service_name, do: "user_service"

  # ============================================================================
  # USER CRUD OPERATIONS
  # ============================================================================

  @doc """
  Get a user by ID with caching.
  """
  def get_user(id) do
    context = ServiceBehavior.build_context(__MODULE__, :get_user, %{user_id: id})

    # Validate user ID format before querying
    case Validator.validate_uuid(id) do
      :ok ->
        cache_key = "user:#{id}"

        # Try to get from cache first
        case Cache.get(cache_key) do
          {:ok, user} ->
            {:ok, user}
          :not_found ->
            # Not in cache, fetch from database
            case ServiceBehavior.get_operation(User, id, :user_not_found, context) do
              {:ok, user} ->
                # Cache the user for 5 minutes
                Cache.put(cache_key, user, ttl: 300)
                {:ok, user}
              error -> error
            end
        end
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
  List users with keyset pagination for better performance and stability.

  Uses cursor-based pagination with inserted_at and id for stable ordering.
  """
  def list_users_keyset(opts \\ []) do
    cursor = opts[:cursor]
    limit = min(opts[:limit] || 20, 100)
    filters = opts[:filters] || %{}

    base_query = User
    |> apply_user_filters(filters)

    query = case cursor do
      nil ->
        # First page
        base_query
        |> order_by([u], desc: u.inserted_at, desc: u.id)
        |> limit(^limit)

      %{inserted_at: cursor_time, id: cursor_id} when is_struct(cursor_time, DateTime) ->
        # Subsequent pages
        base_query
        |> where([u],
          u.inserted_at < ^cursor_time or
          (u.inserted_at == ^cursor_time and u.id < ^cursor_id))
        |> order_by([u], desc: u.inserted_at, desc: u.id)
        |> limit(^limit)

      _ ->
        # Invalid cursor, treat as first page
        base_query
        |> order_by([u], desc: u.inserted_at, desc: u.id)
        |> limit(^limit)
    end

    users = Repo.all(query)

    # Build next cursor if we have results and there might be more
    has_more = length(users) == limit
    next_cursor = if has_more and length(users) > 0 do
      last_user = List.last(users)
      %{
        inserted_at: last_user.inserted_at,
        id: last_user.id
      }
    else
      nil
    end

    %{
      data: users,
      next_cursor: next_cursor,
      has_more: has_more
    }
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
          # Validate role-based password requirements
          role = attrs[:role] || "user"
          with :ok <- validate_password_requirements(attrs, role),
               {:ok, user} <- ServiceBehavior.create_operation(&User.changeset(%User{}, &1), attrs, context) do
            # Log business event
            AppLogger.log_business_event("user_created", %{
              user_id: user.id,
              email: user.email,
              role: user.role,
              correlation_id: context.correlation_id
            })

            {:ok, user}
          end
      end
    end)
  end

  @doc """
  Create a new user with normalized attributes (new approach).
  """
  def create_user_with_normalization(attrs) do
    normalized_attrs = Normalize.user_attrs(attrs)
    context = ServiceBehavior.build_context(__MODULE__, :create_user, %{email: normalized_attrs["email"]})

    ServiceBehavior.with_error_handling(context, fn ->
      # Check if email already exists
      case get_user_by_email(normalized_attrs["email"]) do
        {:ok, _user} ->
          {:error, ErrorHandler.business_error(:email_already_exists, context)}
        {:error, %LedgerBankApi.Core.Error{} = _error} ->
          # User not found, safe to create
          # Validate role-based password requirements
          role = normalized_attrs["role"]
          with :ok <- validate_password_requirements(normalized_attrs, role),
               {:ok, user} <- ServiceBehavior.create_operation(&User.changeset(%User{}, &1), normalized_attrs, context) do
            {:ok, user}
          end
      end
    end)
  end

  @doc """
  Update a user.
  """
  def update_user(user, attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user, %{user_id: user.id})

    ServiceBehavior.with_error_handling(context, fn ->
      case ServiceBehavior.update_operation(&User.update_changeset/2, user, attrs, context) do
        {:ok, updated_user} ->
          # Invalidate cache
          cache_key = "user:#{updated_user.id}"
          Cache.delete(cache_key)

          # Log business event
          AppLogger.log_business_event("user_updated", %{
            user_id: updated_user.id,
            email: updated_user.email,
            updated_fields: Map.keys(attrs),
            correlation_id: context.correlation_id
          })

          {:ok, updated_user}
        error -> error
      end
    end)
  end

  @doc """
  Update a user with normalized attributes (new approach).
  """
  def update_user_with_normalization(user, attrs) do
    normalized_attrs = Normalize.user_update_attrs(attrs)
    context = ServiceBehavior.build_context(__MODULE__, :update_user, %{user_id: user.id})

    ServiceBehavior.update_operation(&User.update_changeset/2, user, normalized_attrs, context)
  end

  @doc """
  Update a user with normalized attributes and policy validation (new approach).
  """
  def update_user_with_normalization_and_policy(user, attrs, current_user) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user_with_permissions, %{user_id: user.id, current_user_id: current_user.id})

    ServiceBehavior.with_error_handling(context, fn ->
      # Validate permissions using Policy module
      with :ok <- validate_update_permissions_with_policy(user, attrs, current_user),
           {:ok, updated_user} <- update_user_with_normalization(user, attrs) do
        {:ok, updated_user}
      end
    end)
  end

  @doc """
  Update a user with permission validation.
  """
  def update_user_with_permissions(user, attrs, current_user) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user_with_permissions, %{user_id: user.id, current_user_id: current_user.id})

    ServiceBehavior.with_error_handling(context, fn ->
      # Validate permissions before updating
      with :ok <- validate_update_permissions(user, attrs, current_user),
           {:ok, updated_user} <- update_user(user, attrs) do
        {:ok, updated_user}
      end
    end)
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

    ServiceBehavior.with_error_handling(context, fn ->
      # Handle nil attributes
      if is_nil(attrs) do
        {:error, ErrorHandler.business_error(:missing_fields, %{
          message: "Password update attributes are required"
        })}
      else
        # Validate current password first
        with :ok <- validate_current_password(user, attrs[:current_password]),
             :ok <- validate_password_change(user, attrs),
             :ok <- validate_password_requirements(attrs, user.role),
             {:ok, updated_user} <- ServiceBehavior.update_operation(&User.password_changeset/2, user, attrs, context) do
          {:ok, updated_user}
        end
      end
    end)
  end

  @doc """
  Update user password for unit tests (bypasses current password validation).
  """
  def update_user_password_for_test(user, attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user_password, %{user_id: user.id})

    ServiceBehavior.with_error_handling(context, fn ->
      # Handle nil attributes
      if is_nil(attrs) do
        {:error, ErrorHandler.business_error(:missing_fields, %{
          message: "Password update attributes are required"
        })}
      else
        # Skip current password validation for unit tests
        with :ok <- validate_password_requirements(attrs, user.role),
             {:ok, updated_user} <- ServiceBehavior.update_operation(&User.password_changeset/2, user, attrs, context) do
          {:ok, updated_user}
        end
      end
    end)
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
            verify_function = if Mix.env() == :test do
              &LedgerBankApi.PasswordHelper.verify_pass/2
            else
              &Argon2.verify_pass/2
            end

            if verify_function.(password, user.password_hash) do
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
  Get user statistics with caching.
  """
  def get_user_statistics do
    cache_key = "user_statistics"

    # Try to get from cache first
    case Cache.get(cache_key) do
      {:ok, stats} ->
        {:ok, stats}
      :not_found ->
        # Not in cache, compute statistics
        total_users = Repo.aggregate(User, :count)
        active_users = Repo.aggregate(from(u in User, where: u.status == "ACTIVE"), :count)
        admin_users = Repo.aggregate(from(u in User, where: u.role == "admin"), :count)

        stats = %{
          total_users: total_users,
          active_users: active_users,
          admin_users: admin_users,
          suspended_users: total_users - active_users
        }

        # Cache the statistics for 1 minute (they change less frequently)
        Cache.put(cache_key, stats, ttl: 60)

        {:ok, stats}
    end
  end

  # ============================================================================
  # OBAN JOB SCHEDULING
  # ============================================================================

  @doc """
  Schedule bank sync for a user.
  """
  def schedule_bank_sync(user_id, opts \\ []) do
    context = ServiceBehavior.build_context(__MODULE__, :schedule_bank_sync, %{user_id: user_id})

    ServiceBehavior.with_error_handling(context, fn ->
      case BankSyncWorker.schedule_sync(user_id, opts) do
        {:ok, job} -> {:ok, job}
        {:error, reason} -> {:error, ErrorHandler.business_error(:internal_server_error, Map.put(context, :reason, reason))}
      end
    end)
  end

  @doc """
  Schedule bank sync with delay.
  """
  def schedule_bank_sync_with_delay(user_id, delay_seconds, opts \\ []) do
    context = ServiceBehavior.build_context(__MODULE__, :schedule_bank_sync_with_delay, %{user_id: user_id, delay_seconds: delay_seconds})

    ServiceBehavior.with_error_handling(context, fn ->
      case BankSyncWorker.schedule_sync_with_delay(user_id, delay_seconds, opts) do
        {:ok, job} -> {:ok, job}
        {:error, reason} -> {:error, ErrorHandler.business_error(:internal_server_error, Map.put(context, :reason, reason))}
      end
    end)
  end

  @doc """
  Schedule payment processing for a user.
  """
  def schedule_payment_processing(payment_id, opts \\ []) do
    context = ServiceBehavior.build_context(__MODULE__, :schedule_payment_processing, %{payment_id: payment_id})

    ServiceBehavior.with_error_handling(context, fn ->
      case PaymentWorker.schedule_payment(payment_id, opts) do
        {:ok, job} -> {:ok, job}
        {:error, reason} -> {:error, ErrorHandler.business_error(:internal_server_error, Map.put(context, :reason, reason))}
      end
    end)
  end

  @doc """
  Schedule payment processing with priority.
  """
  def schedule_payment_processing_with_priority(payment_id, priority, opts \\ []) do
    context = ServiceBehavior.build_context(__MODULE__, :schedule_payment_processing_with_priority, %{payment_id: payment_id, priority: priority})

    ServiceBehavior.with_error_handling(context, fn ->
      case PaymentWorker.schedule_payment_with_priority(payment_id, priority, opts) do
        {:ok, job} -> {:ok, job}
        {:error, reason} -> {:error, ErrorHandler.business_error(:internal_server_error, Map.put(context, :reason, reason))}
      end
    end)
  end

  # ============================================================================
  # PERMISSION VALIDATION
  # ============================================================================

  @doc """
  Validate update permissions for user operations.
  """
  def validate_update_permissions(user, attrs, current_user) do
    # Check if user is trying to change role
    new_role = attrs["role"] || attrs[:role]
    if new_role && new_role != user.role do
      if current_user.role == "admin" do
        :ok
      else
        {:error, ErrorHandler.business_error(:insufficient_permissions, %{message: "Only admins can change user roles"})}
      end
    else
      # Check if user is trying to change status
      new_status = attrs["status"] || attrs[:status]
      if new_status && new_status != user.status do
        if current_user.role == "admin" do
          :ok
        else
          {:error, ErrorHandler.business_error(:insufficient_permissions, %{message: "Only admins can change user status"})}
        end
      else
        :ok
      end
    end
  end

  @doc """
  Validate update permissions using Policy module (new approach).
  """
  def validate_update_permissions_with_policy(user, attrs, current_user) do
    if Policy.can_update_user?(current_user, user, attrs) do
      :ok
    else
      {:error, ErrorHandler.business_error(:insufficient_permissions, %{message: "Insufficient permissions to update user"})}
    end
  end

  @doc """
  Validate current password for password updates.
  """
  def validate_current_password(user, current_password) do
    if current_password do
      case authenticate_user(user.email, current_password) do
        {:ok, _user} -> :ok
        {:error, _error} ->
          {:error, ErrorHandler.business_error(:invalid_credentials, %{
            message: "Current password is incorrect"
          })}
      end
    else
      {:error, ErrorHandler.business_error(:missing_fields, %{
        message: "Current password is required"
      })}
    end
  end

  @doc """
  Validate password change using Policy module (new approach).
  """
  def validate_password_change_with_policy(user, attrs) do
    if Policy.can_change_password?(user, attrs) do
      :ok
    else
      {:error, ErrorHandler.business_error(:invalid_password_format, %{
        message: "Invalid password change request"
      })}
    end
  end

  @doc """
  Update user password with policy validation (new approach).
  """
  def update_user_password_with_policy(user, attrs) do
    context = ServiceBehavior.build_context(__MODULE__, :update_user_password, %{user_id: user.id})

    ServiceBehavior.with_error_handling(context, fn ->
      # Handle nil attributes
      if is_nil(attrs) do
        {:error, ErrorHandler.business_error(:missing_fields, %{
          message: "Password update attributes are required"
        })}
      else
        # Validate using Policy module
        with :ok <- validate_password_change_with_policy(user, attrs),
             :ok <- validate_current_password(user, attrs[:current_password]),
             :ok <- validate_password_requirements(attrs, user.role),
             {:ok, updated_user} <- ServiceBehavior.update_operation(&User.password_changeset/2, user, attrs, context) do
          {:ok, updated_user}
        end
      end
    end)
  end

  @doc """
  Validate that new password is different from current password.
  """
  def validate_password_change(_user, attrs) do
    new_password = attrs["password"] || attrs[:password]
    current_password = attrs[:current_password]

    if new_password && current_password && new_password == current_password do
      {:error, ErrorHandler.business_error(:invalid_password_format, %{
        message: "New password must be different from current password"
      })}
    else
      :ok
    end
  end

  @doc """
  Validate password requirements based on user role.
  """
  def validate_password_requirements(attrs, user_role) do
    password = attrs["password"] || attrs[:password] || attrs["new_password"] || attrs[:new_password]

    if password do
      min_length = if user_role in ["admin", "support"], do: 15, else: 8

      if String.length(password) < min_length do
        {:error, ErrorHandler.business_error(:invalid_password_format, %{
          message: "Password must be at least #{min_length} characters long for #{user_role} users"
        })}
      else
        :ok
      end
    else
      :ok
    end
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

defmodule LedgerBankApi.Core.ServiceBehavior do
  alias LedgerBankApi.Core.ErrorHandler

  @moduledoc """
  Behavior for standardizing service layer error handling patterns.

  This behavior provides consistent error handling, context structure,
  and database operation patterns across all service modules.

  ## Usage

      defmodule MyService do
        @behaviour LedgerBankApi.Core.ServiceBehavior

        # Implement required callbacks
        def service_name, do: "my_service"

        # Use provided macros for consistent error handling
        def get_resource(id) do
          with_error_handling(%{resource_id: id}, fn ->
            case Repo.get(MySchema, id) do
              nil -> {:error, ErrorHandler.business_error(:resource_not_found, %{resource_id: id})}
              resource -> {:ok, resource}
            end
          end)
        end
      end
  """

  @doc """
  Returns the service name for error context and logging.
  """
  @callback service_name() :: String.t()

  @doc """
  Standard context structure for all service operations.
  """
  def standard_context(service_name, operation, additional_context \\ %{}) do
    Map.merge(
      %{
        service: service_name,
        operation: operation,
        timestamp: DateTime.utc_now(),
        correlation_id: LedgerBankApi.Core.Error.generate_correlation_id()
      },
      additional_context
    )
  end

  @doc """
  Build service context using the service's own service_name/0 callback.

  This helper eliminates the repetitive pattern of calling service_name() and standard_context/3
  in every service function.

  ## Examples

      # Instead of:
      context = ServiceBehavior.standard_context(service_name(), :get_user, %{user_id: id})

      # Use:
      context = build_context(:get_user, %{user_id: id})
  """
  def build_context(service_module, operation, additional_context \\ %{}) do
    service_name = service_module.service_name()
    standard_context(service_name, operation, additional_context)
  end

  @doc """
  Wraps a function with standardized error handling.
  """
  defmacro with_error_handling(context, fun) do
    quote do
      LedgerBankApi.Core.ErrorHandler.with_error_handling(
        unquote(fun),
        unquote(context)
      )
    end
  end

  @doc """
  Handle standard service error patterns with consistent error handling.

  This helper eliminates the repetitive error handling pattern used in service functions
  that use `with` statements inside `with_error_handling`.

  ## Examples

      # Instead of:
      ServiceBehavior.with_error_handling(context, fn ->
        with {:ok, result} <- operation() do
          {:ok, result}
        else
          {:error, %LedgerBankApi.Core.Error{} = error} -> {:error, error}
          {:error, reason} -> {:error, ErrorHandler.business_error(:operation_failed, Map.put(context, :reason, reason))}
        end
      end)

      # Use:
      with_standard_error_handling(context, :operation_failed, fn ->
        with {:ok, result} <- operation() do
          {:ok, result}
        end
      end)
  """
  def with_standard_error_handling(context, error_type, operation) do
    with_error_handling(context, fn ->
      case operation.() do
        {:ok, result} ->
          {:ok, result}

        {:error, %LedgerBankApi.Core.Error{} = error} ->
          {:error, error}

        {:error, reason} ->
          {:error, ErrorHandler.business_error(error_type, Map.put(context, :reason, reason))}
      end
    end)
  end

  @doc """
  Standard database operation wrapper for get operations.
  """
  defmacro get_operation(schema, id, not_found_reason, context) do
    quote do
      case LedgerBankApi.Repo.get(unquote(schema), unquote(id)) do
        nil ->
          {:error,
           LedgerBankApi.Core.ErrorHandler.business_error(
             unquote(not_found_reason),
             unquote(context)
           )}

        resource ->
          {:ok, resource}
      end
    end
  end

  @doc """
  Standard database operation wrapper for get_by operations.
  """
  defmacro get_by_operation(schema, conditions, not_found_reason, context) do
    quote do
      case LedgerBankApi.Repo.get_by(unquote(schema), unquote(conditions)) do
        nil ->
          {:error,
           LedgerBankApi.Core.ErrorHandler.business_error(
             unquote(not_found_reason),
             unquote(context)
           )}

        resource ->
          {:ok, resource}
      end
    end
  end

  @doc """
  Standard database operation wrapper for create operations.
  """
  defmacro create_operation(changeset_fun, attrs, context) do
    quote do
      case unquote(changeset_fun).(unquote(attrs)) do
        %Ecto.Changeset{valid?: true} = changeset ->
          case LedgerBankApi.Repo.insert(changeset) do
            {:ok, resource} ->
              {:ok, resource}

            {:error, changeset} ->
              {:error,
               LedgerBankApi.Core.ErrorHandler.handle_changeset_error(changeset, unquote(context))}
          end

        %Ecto.Changeset{valid?: false} = changeset ->
          {:error,
           LedgerBankApi.Core.ErrorHandler.handle_changeset_error(changeset, unquote(context))}
      end
    end
  end

  @doc """
  Standard database operation wrapper for update operations.
  """
  defmacro update_operation(changeset_fun, resource, attrs, context) do
    quote do
      case unquote(changeset_fun).(unquote(resource), unquote(attrs)) do
        %Ecto.Changeset{valid?: true} = changeset ->
          case LedgerBankApi.Repo.update(changeset) do
            {:ok, resource} ->
              {:ok, resource}

            {:error, changeset} ->
              {:error,
               LedgerBankApi.Core.ErrorHandler.handle_changeset_error(changeset, unquote(context))}
          end

        %Ecto.Changeset{valid?: false} = changeset ->
          {:error,
           LedgerBankApi.Core.ErrorHandler.handle_changeset_error(changeset, unquote(context))}
      end
    end
  end

  @doc """
  Standard database operation wrapper for delete operations.
  """
  defmacro delete_operation(resource, context) do
    quote do
      case LedgerBankApi.Repo.delete(unquote(resource)) do
        {:ok, resource} ->
          {:ok, resource}

        {:error, changeset} ->
          {:error,
           LedgerBankApi.Core.ErrorHandler.handle_changeset_error(changeset, unquote(context))}
      end
    end
  end

  @doc """
  Standard list operation wrapper with filters, sorting, and pagination.
  """
  defmacro list_operation(base_query, opts, context) do
    quote do
      try do
        query =
          unquote(base_query)
          |> apply_filters(unquote(opts)[:filters])
          |> apply_sorting(unquote(opts)[:sort])
          |> apply_pagination(unquote(opts)[:pagination])

        results = Repo.all(query)
        {:ok, results}
      rescue
        error ->
          {:error,
           ErrorHandler.business_error(
             :database_error,
             Map.put(unquote(context), :original_error, inspect(error))
           )}
      end
    end
  end

  @doc """
  Standard business rule validation wrapper.
  """
  defmacro validate_business_rule(condition, error_reason, context) do
    quote do
      if unquote(condition) do
        {:error, ErrorHandler.business_error(unquote(error_reason), unquote(context))}
      else
        :ok
      end
    end
  end

  @doc """
  Standard external service call wrapper with timeout and error handling.
  """
  defmacro external_service_call(service_fun, timeout_ms \\ 30000, context) do
    quote do
      try do
        result = Task.await(Task.async(unquote(service_fun)), unquote(timeout_ms))
        {:ok, result}
      rescue
        :timeout ->
          {:error, ErrorHandler.timeout_error(unquote(context), unquote(timeout_ms))}

        error ->
          {:error,
           ErrorHandler.business_error(
             :service_unavailable,
             Map.put(unquote(context), :original_error, inspect(error))
           )}
      end
    end
  end
end

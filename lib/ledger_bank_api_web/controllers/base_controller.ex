defmodule LedgerBankApiWeb.BaseController do
  @moduledoc """
  Enhanced base controller providing advanced CRUD operations, query optimization, and error handling.
  Eliminates code duplication and provides consistent patterns across all controllers.
  """

  use LedgerBankApiWeb, :controller

  alias LedgerBankApi.Banking.Behaviours.ErrorHandler

  @doc """
  Macro to define standard CRUD operations for a resource with advanced features.
  """
  defmacro crud_operations(context_module, schema_module, resource_name, opts \\ []) do
    quote do
      @context_module unquote(context_module)
      @schema_module unquote(schema_module)
      @resource_name unquote(resource_name)
      @opts unquote(opts)

      @doc """
      List all resources with pagination, filtering, and sorting.
      """
      def index(conn, params) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"list_#{@resource_name}", user_id: user_id}

        case ErrorHandler.with_error_handling(fn ->
          # Check authorization for listing resources
          maybe_authorize_list_access(user_id, @opts[:authorization])
          list_resources_with_filters(params, user_id, @opts)
        end, context) do
          {:ok, response} ->
            json(conn, response.data)
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Get a specific resource by ID with preloading.
      """
      def show(conn, %{"id" => id}) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"get_#{@resource_name}", user_id: user_id, resource_id: id}

        case ErrorHandler.with_error_handling(fn ->
          resource = get_resource_with_preloads(id, @opts[:preloads])
          maybe_authorize_access(resource, user_id, @opts[:authorization])
          resource
        end, context) do
          {:ok, response} ->
            json(conn, response.data)
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Create a new resource with validation.
      """
      def create(conn, %{@resource_name => params}) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"create_#{@resource_name}", user_id: user_id}

        # Add user_id to params if specified
        params = maybe_add_user_id(params, user_id, @opts[:user_field])

        case ErrorHandler.with_error_handling(fn ->
          @context_module.create(params)
        end, context) do
          {:ok, response} ->
            conn
            |> put_status(201)
            |> json(response.data)
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Update a resource with validation.
      """
      def update(conn, %{"id" => id} = params) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"update_#{@resource_name}", user_id: user_id, resource_id: id}

        case ErrorHandler.with_error_handling(fn ->
          resource = @context_module.get!(id)
          maybe_authorize_access(resource, user_id, @opts[:authorization])
          @context_module.update(resource, params[@resource_name] || %{})
        end, context) do
          {:ok, response} ->
            json(conn, response.data)
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Delete a resource with cascade handling.
      """
      def delete(conn, %{"id" => id}) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"delete_#{@resource_name}", user_id: user_id, resource_id: id}

        case ErrorHandler.with_error_handling(fn ->
          resource = @context_module.get!(id)
          maybe_authorize_access(resource, user_id, @opts[:authorization])
          @context_module.delete(resource)
        end, context) do
          {:ok, response} ->
            json(conn, response.data)
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      # Private helper functions

      defp list_resources_with_filters(params, user_id, opts) do
        # Apply pagination, filtering, and sorting
        with {:ok, pagination} <- extract_pagination(params),
             {:ok, filters} <- extract_filters(params, opts),
             {:ok, sorting} <- extract_sorting(params, opts) do

          @context_module.list_with_filters(pagination, filters, sorting, user_id, opts[:user_filter])
        end
      end

      defp get_resource_with_preloads(id, preloads) do
        case preloads do
          nil -> @context_module.get!(id)
          preloads -> @context_module.get_with_preloads!(id, preloads)
        end
      end

      defp extract_pagination(params) do
        page = String.to_integer(params["page"] || "1")
        per_page = String.to_integer(params["per_page"] || "20")

        if page > 0 and per_page > 0 and per_page <= 100 do
          {:ok, %{page: page, per_page: per_page}}
        else
          {:error, "Invalid pagination parameters"}
        end
      end

      defp extract_filters(params, opts) do
        allowed_filters = opts[:allowed_filters] || []
        filters = Map.take(params, allowed_filters)
        {:ok, filters}
      end

      defp extract_sorting(params, opts) do
        allowed_fields = opts[:allowed_sort_fields] || []
        sort_by = params["sort_by"] || opts[:default_sort_field] || "inserted_at"
        sort_order = params["sort_order"] || "desc"

        if sort_by in allowed_fields and sort_order in ["asc", "desc"] do
          {:ok, %{sort_by: sort_by, sort_order: sort_order}}
        else
          {:error, "Invalid sorting parameters"}
        end
      end

      defp maybe_filter_by_user(data, user_id, nil), do: data
      defp maybe_filter_by_user(data, user_id, filter_fun) when is_function(filter_fun, 2) do
        filter_fun.(data, user_id)
      end
      defp maybe_filter_by_user(data, user_id, :user_id) do
        Enum.filter(data, fn item ->
          item_user_id = if Map.has_key?(item, :user_id), do: item.user_id, else: item.id
          item_user_id == user_id
        end)
      end

      defp maybe_add_user_id(params, user_id, nil), do: params
      defp maybe_add_user_id(params, user_id, field) when is_atom(field) do
        Map.put(params, Atom.to_string(field), user_id)
      end

      defp maybe_authorize_access(resource, user_id, nil), do: :ok
      defp maybe_authorize_access(resource, user_id, :user_ownership) do
        # For User schema, the field is 'id', not 'user_id'
        resource_user_id = if Map.has_key?(resource, :user_id), do: resource.user_id, else: resource.id
        if resource_user_id != user_id do
          raise "Unauthorized access to resource"
        end
      end
      defp maybe_authorize_access(resource, user_id, :admin_only) do
        current_user = get_current_user(user_id)
        if current_user.role != "admin", do: raise "Unauthorized: Admin role required"
      end
      defp maybe_authorize_access(resource, user_id, :admin_or_owner) do
        current_user = get_current_user(user_id)
        # For User schema, the field is 'id', not 'user_id'
        resource_user_id = if Map.has_key?(resource, :user_id), do: resource.user_id, else: resource.id
        unless resource_user_id == user_id do
          # Debug logging
          require Logger
          Logger.debug("Authorization check failed", %{
            current_user_id: user_id,
            resource_user_id: resource_user_id,
            current_user_role: current_user.role,
            resource: inspect(resource)
          })
          if current_user.role != "admin", do: raise "Unauthorized: Admin role required"
        end
      end

      # Authorization for list operations (when no specific resource is involved)
      defp maybe_authorize_list_access(user_id, nil), do: :ok
      defp maybe_authorize_list_access(user_id, :user_ownership) do
        # For list operations, user_ownership means they can only see their own resources
        # This is handled by the user_filter in the context
        :ok
      end
      defp maybe_authorize_list_access(user_id, :admin_only) do
        current_user = get_current_user(user_id)
        if current_user.role != "admin", do: raise "Unauthorized: Admin role required"
      end
      defp maybe_authorize_list_access(user_id, :admin_or_owner) do
        # For list operations, admin_or_owner means only admins can list all resources
        current_user = get_current_user(user_id)
        if current_user.role != "admin", do: raise "Unauthorized: Admin role required"
      end

      defp get_current_user(user_id) do
        LedgerBankApi.Users.Context.get!(user_id)
      end

      defp handle_error_response(conn, error_response, context) do
        response = ErrorHandler.handle_common_error(error_response, context)
        status_code = get_error_status_code(response)
        conn |> put_status(status_code) |> json(response)
      end

      defp get_error_status_code(%{error: %{type: type}}) do
        case type do
          :validation_error -> 422
          :not_found -> 404
          :unauthorized -> 401
          :forbidden -> 403
          :conflict -> 409
          :unprocessable_entity -> 422
          _ -> 500
        end
      end
      defp get_error_status_code(_), do: 500
    end
  end

  @doc """
  Macro to define custom actions with standard error handling.
  """
  defmacro custom_action(name, do: block) do
    quote do
      def unquote(name)(conn, params) do
        user_id = conn.assigns.current_user_id
        context = %{action: unquote(name), user_id: user_id}

        case ErrorHandler.with_error_handling(fn ->
          unquote(block)
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
  end

  @doc """
  Macro to define async actions (like job queuing) with standard error handling.
  """
  defmacro async_action(name, do: block) do
    quote do
      def unquote(name)(conn, params) do
        user_id = conn.assigns.current_user_id
        context = %{action: unquote(name), user_id: user_id}

        case ErrorHandler.with_error_handling(fn ->
          unquote(block)
        end, context) do
          {:ok, response} ->
            conn
            |> put_status(202)
            |> json(response.data)
          {:error, error_response} ->
            response = ErrorHandler.handle_common_error(error_response, context)
            conn |> put_status(400) |> json(response)
        end
      end
    end
  end
end

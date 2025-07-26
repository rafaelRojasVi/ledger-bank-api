defmodule LedgerBankApiWeb.BaseController do
  @moduledoc """
  Base controller providing common CRUD operations and error handling patterns.
  Reduces code duplication across all controllers.
  """

  use LedgerBankApiWeb, :controller

  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  alias LedgerBankApi.Helpers.AuthorizationHelpers

  @doc """
  Macro to define standard CRUD operations for a resource.
  """
  defmacro crud_operations(context_module, schema_module, resource_name, opts \\ []) do
    quote do
      @context_module unquote(context_module)
      @schema_module unquote(schema_module)
      @resource_name unquote(resource_name)
      @opts unquote(opts)

      @doc """
      List all resources for the current user.
      """
      def index(conn, params) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"list_#{@resource_name}", user_id: user_id}

        case ErrorHandler.with_error_handling(fn ->
          @context_module.list()
          |> maybe_filter_by_user(user_id, @opts[:user_filter])
        end, context) do
          {:ok, response} ->
            render(conn, :index, %{@resource_name => response.data})
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Get a specific resource by ID.
      """
      def show(conn, %{"id" => id}) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"get_#{@resource_name}", user_id: user_id, resource_id: id}

        case ErrorHandler.with_error_handling(fn ->
          resource = @context_module.get!(id)
          maybe_authorize_access(resource, user_id, @opts[:authorization])
          resource
        end, context) do
          {:ok, response} ->
            render(conn, :show, %{@resource_name => response.data})
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Create a new resource.
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
            |> render(:show, %{@resource_name => response.data})
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Update a resource.
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
            render(conn, :show, %{@resource_name => response.data})
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      @doc """
      Delete a resource.
      """
      def delete(conn, %{"id" => id}) do
        user_id = conn.assigns.current_user_id
        context = %{action: :"delete_#{@resource_name}", user_id: user_id, resource_id: id}

        case ErrorHandler.with_error_handling(fn ->
          resource = @context_module.get!(id)
          maybe_authorize_access(resource, user_id, @opts[:authorization])
          @context_module.delete(resource)
        end, context) do
          {:ok, _response} ->
            conn
            |> put_status(204)
            |> send_resp(:no_content, "")
          {:error, error_response} ->
            handle_error_response(conn, error_response, context)
        end
      end

      # Private helper functions

      defp maybe_filter_by_user(data, user_id, nil), do: data
      defp maybe_filter_by_user(data, user_id, filter_fun) when is_function(filter_fun, 2) do
        filter_fun.(data, user_id)
      end
      defp maybe_filter_by_user(data, user_id, :user_id) do
        Enum.filter(data, fn item -> item.user_id == user_id end)
      end

      defp maybe_add_user_id(params, user_id, nil), do: params
      defp maybe_add_user_id(params, user_id, field) when is_atom(field) do
        Map.put(params, Atom.to_string(field), user_id)
      end

      defp maybe_authorize_access(resource, user_id, nil), do: :ok
      defp maybe_authorize_access(resource, user_id, :user_ownership) do
        if resource.user_id != user_id do
          raise "Unauthorized access to resource"
        end
      end
      defp maybe_authorize_access(resource, user_id, :admin_only) do
        current_user = get_current_user(user_id)
        AuthorizationHelpers.require_role!(current_user, "admin")
      end
      defp maybe_authorize_access(resource, user_id, :admin_or_owner) do
        current_user = get_current_user(user_id)
        unless resource.user_id == user_id do
          AuthorizationHelpers.require_role!(current_user, "admin")
        end
      end

      defp get_current_user(user_id) do
        LedgerBankApi.Users.Context.get_user!(user_id)
      end

      defp handle_error_response(conn, error_response, context) do
        {status, response} = ErrorHandler.handle_error(error_response, context, [])
        conn |> put_status(status) |> json(response)
      end
    end
  end

  @doc """
  Macro to define custom actions with standard error handling.
  """
  defmacro action(name, do: block) do
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
            {status, response} = ErrorHandler.handle_error(error_response, context, [])
            conn |> put_status(status) |> json(response)
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
            {status, response} = ErrorHandler.handle_error(error_response, context, [])
            conn |> put_status(status) |> json(response)
        end
      end
    end
  end

  @doc """
  Helper to create a success response with optional message.
  """
  def success_response(data, message \\ nil) do
    response = %{data: data}
    if message, do: Map.put(response, :message, message), else: response
  end

  @doc """
  Helper to create a job queuing response.
  """
  def job_response(job_type, resource_id, message \\ nil) do
    success_response(%{
      message: message || "#{job_type} initiated",
      "#{job_type}_id": resource_id,
      status: "queued"
    })
  end
end

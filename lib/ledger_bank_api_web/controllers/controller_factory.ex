defmodule LedgerBankApiWeb.ControllerFactory do
  @moduledoc """
  Factory for generating optimized controllers with consistent patterns.
  Eliminates code duplication and provides standardized CRUD operations.
  """

  @doc """
  Generates a complete controller module with all CRUD operations and custom actions.
  """
  defmacro generate_controller(module_name, context_module, schema_module, resource_name, opts \\ []) do
    quote do
      defmodule unquote(module_name) do
        @moduledoc """
        Generated controller for #{unquote(resource_name)} with optimized CRUD operations.
        """

        use LedgerBankApiWeb, :controller
        import LedgerBankApiWeb.BaseController
        import LedgerBankApiWeb.JSON.BaseJSON
        import LedgerBankApiWeb.ResponseHelpers

        alias unquote(context_module)

        # Standard CRUD operations with advanced features
        crud_operations(
          unquote(context_module),
          unquote(schema_module),
          unquote(resource_name),
          unquote(opts)
        )

        # Generate custom actions based on options
        unquote(generate_custom_actions(opts))

        # Generate relationship endpoints if specified
        unquote(generate_relationship_endpoints(opts))
      end
    end
  end

  @doc """
  Generates a simple resource controller with basic CRUD.
  """
  defmacro generate_simple_controller(module_name, context_module, schema_module, resource_name, opts \\ []) do
    quote do
      defmodule unquote(module_name) do
        @moduledoc """
        Simple controller for #{unquote(resource_name)} with basic CRUD operations.
        """

        use LedgerBankApiWeb, :controller
        import LedgerBankApiWeb.BaseController
        import LedgerBankApiWeb.JSON.BaseJSON

        alias unquote(context_module)

        # Basic CRUD operations
        crud_operations(
          unquote(context_module),
          unquote(schema_module),
          unquote(resource_name),
          unquote(opts)
        )
      end
    end
  end

  # Private helper functions

  defp generate_custom_actions(opts) do
    actions = opts[:actions] || []

    Enum.map(actions, fn {action_name, action_opts} ->
      generate_action(action_name, action_opts)
    end)
  end

  defp generate_action(action_name, action_opts) do
    quote do
      action unquote(action_name) do
        unquote(action_opts[:logic])
      end
    end
  end

  defp generate_relationship_endpoints(opts) do
    relationships = opts[:relationships] || []

    Enum.map(relationships, fn {relationship_name, relationship_opts} ->
      generate_relationship_endpoint(relationship_name, relationship_opts)
    end)
  end

  defp generate_relationship_endpoint(relationship_name, relationship_opts) do
    quote do
      action unquote(relationship_name) do
        resource = @context_module.get!(params["id"])
        maybe_authorize_access(resource, user_id, @opts[:authorization])

        @context_module.unquote(relationship_opts[:function])(resource.id, params)
      end
    end
  end
end

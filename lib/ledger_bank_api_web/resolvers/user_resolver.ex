defmodule LedgerBankApiWeb.Resolvers.UserResolver do
  @moduledoc """
  GraphQL resolvers for user-related operations.
  """

  require Logger

  alias LedgerBankApi.Accounts.UserService

  def find(%{id: id}, %{context: %{current_user: current_user}}) do
    case UserService.get_user(id) do
      {:ok, user} ->
        # Check if user can access this user's data
        if can_access_user?(current_user, user) do
          {:ok, user}
        else
          {:error, "Access denied"}
        end

      {:error, _reason} ->
        {:error, "User not found"}
    end
  end

  def find(%{id: _id}, _resolution) do
    {:error, "Authentication required"}
  end

  def list(%{limit: limit, offset: offset}, %{context: %{current_user: current_user}}) do
    if can_list_users?(current_user) do
      users = UserService.list_users(%{limit: limit, offset: offset})
      {:ok, users}
    else
      {:error, "Access denied"}
    end
  end

  def list(_args, _resolution) do
    {:error, "Authentication required"}
  end

  def me(_args, %{context: %{current_user: user}}) do
    {:ok, user}
  end

  def me(_args, _resolution) do
    {:error, "Authentication required"}
  end

  def create(%{input: input}, _resolution) do
    case UserService.create_user(input) do
      {:ok, user} ->
        {:ok, %{success: true, user: user, errors: []}}

      {:error, %LedgerBankApi.Core.Error{} = error} ->
        {:ok, %{success: false, user: nil, errors: [error.message]}}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:ok, %{success: false, user: nil, errors: errors}}
    end
  end

  def update(%{id: id, input: input}, %{context: %{current_user: current_user}}) do
    case UserService.get_user(id) do
      {:ok, user} ->
        if can_update_user?(current_user, user) do
          case UserService.update_user(user, input) do
            {:ok, updated_user} ->
              {:ok, %{success: true, user: updated_user, errors: []}}

            {:error, changeset} ->
              errors = format_changeset_errors(changeset)
              {:ok, %{success: false, user: nil, errors: errors}}
          end
        else
          {:error, "Access denied"}
        end

      {:error, _reason} ->
        {:error, "User not found"}
    end
  end

  def update(_args, _resolution) do
    {:error, "Authentication required"}
  end

  # Private helper functions

  defp can_access_user?(current_user, target_user) do
    # Users can access their own data, admins can access any user's data
    current_user.id == target_user.id || current_user.role == "admin"
  end

  defp can_list_users?(current_user) do
    # Only admins can list all users
    current_user.role == "admin"
  end

  defp can_update_user?(current_user, target_user) do
    # Users can update their own data, admins can update any user's data
    current_user.id == target_user.id || current_user.role == "admin"
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} ->
      "#{field}: #{message}"
    end)
  end
end

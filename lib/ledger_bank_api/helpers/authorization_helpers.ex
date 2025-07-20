defmodule LedgerBankApi.Helpers.AuthorizationHelpers do
  @moduledoc """
  Macros and helpers for role-based authorization in business logic.
  Usage:
    require_role!(user, "admin")
  Raises a standardized forbidden error if the user does not have the required role.
  """

  defmacro require_role!(user, role) do
    quote do
      unless LedgerBankApi.Users.User.has_role?(unquote(user), unquote(role)) do
        raise "Insufficient permissions"
      end
    end
  end
end

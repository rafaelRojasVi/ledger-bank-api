defmodule LedgerBankApi.Accounts.UserQueries do
  @moduledoc """
  Query building module for User resources.

  Uses Queryable behaviour to provide consistent filtering, sorting, and pagination.

  ## Usage

      # In UserService
      def list_users(opts \\ []) do
        User
        |> UserQueries.apply_filters(opts[:filters])
        |> UserQueries.apply_sorting(opts[:sort])
        |> UserQueries.apply_pagination(opts[:pagination])
        |> Repo.all()
      end

  ## Example Filters

      filters = %{
        status: "ACTIVE",
        role: "admin",
        verified: true
      }
  """

  use LedgerBankApi.Core.Queryable

  @impl true
  def filterable_fields do
    %{
      status: :string,
      role: :string,
      active: :boolean,
      verified: :boolean,
      suspended: :boolean,
      deleted: :boolean
    }
  end

  @impl true
  def sortable_fields do
    [:email, :full_name, :status, :role, :inserted_at, :updated_at]
  end
end

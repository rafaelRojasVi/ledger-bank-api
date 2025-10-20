defmodule LedgerBankApiWeb.Schema do
  @moduledoc """
  GraphQL schema definition using Absinthe.

  Provides GraphQL API for querying and mutating data.
  """

  use Absinthe.Schema
  require Logger

  # Import types
  import_types(LedgerBankApiWeb.Schema.Types)

  # Query root type
  query do
    field :user, :user do
      arg(:id, non_null(:id))
      resolve(&LedgerBankApiWeb.Resolvers.UserResolver.find/2)
    end

    field :users, list_of(:user) do
      arg(:limit, :integer, default_value: 10)
      arg(:offset, :integer, default_value: 0)
      resolve(&LedgerBankApiWeb.Resolvers.UserResolver.list/2)
    end

    field :me, :user do
      resolve(&LedgerBankApiWeb.Resolvers.UserResolver.me/2)
    end

    field :payments, list_of(:payment) do
      arg(:limit, :integer, default_value: 10)
      arg(:offset, :integer, default_value: 0)
      resolve(&LedgerBankApiWeb.Resolvers.PaymentResolver.list/2)
    end

    field :payment, :payment do
      arg(:id, non_null(:id))
      resolve(&LedgerBankApiWeb.Resolvers.PaymentResolver.find/2)
    end

    field :accounts, list_of(:account) do
      resolve(&LedgerBankApiWeb.Resolvers.AccountResolver.list/2)
    end

    field :transactions, list_of(:transaction) do
      arg(:account_id, :id)
      arg(:limit, :integer, default_value: 10)
      arg(:offset, :integer, default_value: 0)
      resolve(&LedgerBankApiWeb.Resolvers.TransactionResolver.list/2)
    end
  end

  # Mutation root type
  mutation do
    field :create_user, type: :user_result do
      arg(:input, non_null(:user_input))
      resolve(&LedgerBankApiWeb.Resolvers.UserResolver.create/2)
    end

    field :update_user, type: :user_result do
      arg(:id, non_null(:id))
      arg(:input, non_null(:user_update_input))
      resolve(&LedgerBankApiWeb.Resolvers.UserResolver.update/2)
    end

    field :create_payment, type: :payment_result do
      arg(:input, non_null(:payment_input))
      resolve(&LedgerBankApiWeb.Resolvers.PaymentResolver.create/2)
    end

    field :cancel_payment, type: :payment_result do
      arg(:id, non_null(:id))
      resolve(&LedgerBankApiWeb.Resolvers.PaymentResolver.cancel/2)
    end

    field :login, type: :auth_result do
      arg(:email, non_null(:string))
      arg(:password, non_null(:string))
      resolve(&LedgerBankApiWeb.Resolvers.AuthResolver.login/2)
    end

    field :refresh_token, type: :auth_result do
      arg(:refresh_token, non_null(:string))
      resolve(&LedgerBankApiWeb.Resolvers.AuthResolver.refresh/2)
    end
  end

  # Subscription root type
  subscription do
    field :payment_status_changed, :payment do
      arg(:payment_id, :id)
      arg(:user_id, :id)

      resolve(fn payment, _args, _resolution ->
        {:ok, payment}
      end)
    end

    field :balance_updated, :account do
      arg(:account_id, :id)
      arg(:user_id, :id)

      resolve(fn account, _args, _resolution ->
        {:ok, account}
      end)
    end

    field :user_created, :user do
      resolve(fn user, _args, _resolution ->
        {:ok, user}
      end)
    end
  end
end

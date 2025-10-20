defmodule LedgerBankApiWeb.Schema.Types do
  @moduledoc """
  GraphQL type definitions for the API.
  """

  use Absinthe.Schema.Notation

  # Scalar types
  scalar :datetime, description: "ISO 8601 datetime" do
    serialize(&DateTime.to_iso8601/1)

    parse(fn input ->
      case DateTime.from_iso8601(input.value) do
        {:ok, datetime, _} -> {:ok, datetime}
        _ -> :error
      end
    end)
  end

  scalar :decimal, description: "Decimal number" do
    serialize(&Decimal.to_string/1)

    parse(fn input ->
      case Decimal.parse(input.value) do
        {decimal, ""} -> {:ok, decimal}
        _ -> :error
      end
    end)
  end

  # User types
  object :user do
    field(:id, :id)
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:role, :string)
    field(:created_at, :datetime)
    field(:updated_at, :datetime)
    field(:last_login_at, :datetime)

    field :payments, list_of(:payment) do
      resolve(fn _user, _args, _resolution ->
        # This would be resolved through a separate query
        {:ok, []}
      end)
    end

    field :accounts, list_of(:account) do
      resolve(fn _user, _args, _resolution ->
        # This would be resolved through a separate query
        {:ok, []}
      end)
    end
  end

  input_object :user_input do
    field(:email, non_null(:string))
    field(:password, non_null(:string))
    field(:first_name, :string)
    field(:last_name, :string)
    field(:role, :string)
  end

  input_object :user_update_input do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
  end

  # Payment types
  object :payment do
    field(:id, :id)
    field(:amount, :decimal)
    field(:currency, :string)
    field(:status, :string)
    field(:direction, :string)
    field(:description, :string)
    field(:reference, :string)
    field(:created_at, :datetime)
    field(:updated_at, :datetime)
    field(:processed_at, :datetime)

    field :user, :user do
      resolve(fn _payment, _args, _resolution ->
        # This would be resolved through a separate query
        {:ok, nil}
      end)
    end

    field :account, :account do
      resolve(fn _payment, _args, _resolution ->
        # This would be resolved through a separate query
        {:ok, nil}
      end)
    end
  end

  input_object :payment_input do
    field(:amount, non_null(:decimal))
    field(:currency, non_null(:string))
    field(:description, non_null(:string))
    field(:account_id, non_null(:id))
    field(:reference, :string)
  end

  # Account types
  object :account do
    field(:id, :id)
    field(:account_name, :string)
    field(:account_number, :string)
    field(:sort_code, :string)
    field(:balance, :decimal)
    field(:currency, :string)
    field(:bank_name, :string)
    field(:created_at, :datetime)
    field(:updated_at, :datetime)

    field :user, :user do
      resolve(fn _account, _args, _resolution ->
        # This would be resolved through a separate query
        {:ok, nil}
      end)
    end

    field :transactions, list_of(:transaction) do
      resolve(fn _account, _args, _resolution ->
        # This would be resolved through a separate query
        {:ok, []}
      end)
    end
  end

  # Transaction types
  object :transaction do
    field(:id, :id)
    field(:amount, :decimal)
    field(:currency, :string)
    field(:description, :string)
    field(:transaction_type, :string)
    field(:status, :string)
    field(:reference, :string)
    field(:created_at, :datetime)
    field(:updated_at, :datetime)

    field :account, :account do
      resolve(fn _transaction, _args, _resolution ->
        # This would be resolved through a separate query
        {:ok, nil}
      end)
    end
  end

  # Authentication types
  object :auth_result do
    field(:success, :boolean)
    field(:access_token, :string)
    field(:refresh_token, :string)
    field(:expires_in, :integer)
    field(:user, :user)
    field(:errors, list_of(:string))
  end

  # Result types with error handling
  object :user_result do
    field(:success, :boolean)
    field(:user, :user)
    field(:errors, list_of(:string))
  end

  object :payment_result do
    field(:success, :boolean)
    field(:payment, :payment)
    field(:errors, list_of(:string))
  end

  # Error types
  object :error do
    field(:field, :string)
    field(:message, :string)
    field(:code, :string)
  end
end

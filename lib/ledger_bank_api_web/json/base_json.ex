defmodule LedgerBankApiWeb.JSON.BaseJSON do
  @moduledoc """
  Base JSON module providing standardized response formatting and common data transformations.
  Reduces duplication across JSON views.
  """

  @doc """
  Standard response wrapper for list endpoints.
  """
  def list_response(data, resource_name) do
    %{data: Enum.map(data, &format_resource(&1, resource_name))}
  end

  @doc """
  Standard response wrapper for single resource endpoints.
  """
  def show_response(data, resource_name) do
    %{data: format_resource(data, resource_name)}
  end

  @doc """
  Standard response wrapper for paginated endpoints.
  """
  def paginated_response(data, pagination, resource_name) do
    %{
      data: Enum.map(data, &format_resource(&1, resource_name)),
      pagination: pagination
    }
  end

  @doc """
  Standard response wrapper for relationships.
  """
  def relationship_response(data, resource_name) do
    %{data: format_resource(data, resource_name)}
  end

  @doc """
  Format user data consistently across all endpoints.
  """
  def format_user(user) do
    %{
      id: user.id,
      email: user.email,
      full_name: user.full_name,
      role: user.role,
      status: user.status,
      created_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  @doc """
  Format bank data consistently.
  """
  def format_bank(bank) do
    %{
      id: bank.id,
      name: bank.name,
      country: bank.country,
      logo_url: bank.logo_url,
      status: bank.status,
      code: bank.code
    }
  end

  @doc """
  Format bank branch data consistently.
  """
  def format_bank_branch(branch) do
    %{
      id: branch.id,
      name: branch.name,
      country: branch.country,
      iban: branch.iban,
      swift_code: branch.swift_code,
      routing_number: branch.routing_number,
      bank: format_bank(branch.bank)
    }
  end

  @doc """
  Format account data consistently.
  """
  def format_account(account) do
    %{
      id: account.id,
      name: account.account_name,
      status: account.status,
      type: account.account_type,
      currency: account.currency,
      institution: %{
        id: account.user_bank_login.bank_branch.bank.id,
        name: account.user_bank_login.bank_branch.bank.name
      },
      last_four: account.last_four,
      balance: account.balance,
      last_sync_at: account.last_sync_at,
      links: build_account_links(account.id)
    }
  end

  @doc """
  Format transaction data consistently.
  """
  def format_transaction(transaction) do
    %{
      id: transaction.id,
      account_id: transaction.account_id,
      description: transaction.description,
      amount: transaction.amount,
      direction: transaction.direction,
      posted_at: transaction.posted_at,
      type: "transaction",
      created_at: transaction.inserted_at
    }
  end

  @doc """
  Format payment data consistently.
  """
  def format_payment(payment) do
    %{
      id: payment.id,
      amount: payment.amount,
      direction: payment.direction,
      description: payment.description,
      payment_type: payment.payment_type,
      status: payment.status,
      posted_at: payment.posted_at,
      external_transaction_id: payment.external_transaction_id,
      user_bank_account: format_account_summary(payment.user_bank_account),
      created_at: payment.inserted_at,
      updated_at: payment.updated_at
    }
  end

  @doc """
  Format user bank login data consistently.
  """
  def format_user_bank_login(login) do
    %{
      id: login.id,
      username: login.username,
      status: login.status,
      last_sync_at: login.last_sync_at,
      sync_frequency: login.sync_frequency,
      bank_branch: format_bank_branch(login.bank_branch),
      created_at: login.inserted_at,
      updated_at: login.updated_at
    }
  end

  @doc """
  Format authentication response with tokens.
  """
  def format_auth_response(user, access_token, refresh_token, message) do
    %{
      data: %{
        user: format_user(user),
        access_token: access_token,
        refresh_token: refresh_token
      },
      message: message
    }
  end

  @doc """
  Format logout response.
  """
  def format_logout_response do
    %{
      message: "Logout successful",
      data: %{}
    }
  end

  @doc """
  Format job queuing response.
  """
  def format_job_response(job_type, resource_id, message \\ nil) do
    %{
      message: message || "#{job_type} initiated",
      "#{job_type}_id": resource_id,
      status: "queued"
    }
  end

  @doc """
  Format balance response.
  """
  def format_balance_response(account) do
    %{
      data: %{
        account_id: account.id,
        balance: account.balance,
        currency: account.currency,
        last_updated: account.last_sync_at
      }
    }
  end

  # Private helper functions

  defp format_resource(data, resource_name) do
    case resource_name do
      :user -> format_user(data)
      :account -> format_account(data)
      :transaction -> format_transaction(data)
      :payment -> format_payment(data)
      :user_bank_login -> format_user_bank_login(data)
      :bank -> format_bank(data)
      :bank_branch -> format_bank_branch(data)
      _ -> data
    end
  end

  defp format_account_summary(account) do
    %{
      id: account.id,
      account_name: account.account_name,
      last_four: account.last_four,
      currency: account.currency
    }
  end

  defp build_account_links(account_id) do
    %{
      self: "/api/accounts/#{account_id}",
      transactions: "/api/accounts/#{account_id}/transactions",
      balances: "/api/accounts/#{account_id}/balances",
      payments: "/api/accounts/#{account_id}/payments"
    }
  end
end

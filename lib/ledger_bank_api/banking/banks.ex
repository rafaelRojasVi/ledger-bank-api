defmodule LedgerBankApi.Banking.Banks do
  @moduledoc """
  Enhanced business logic for banks with standardized return patterns.
  All functions return {:ok, data} or {:error, reason}.
  """
  alias LedgerBankApi.Banking.Schemas.Bank
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  import Ecto.Query
  use LedgerBankApi.CrudHelpers, schema: Bank

  @doc """
  Lists active banks with standardized return pattern.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_active_banks do
    context = %{action: :list_active_banks}

    ErrorHandler.with_error_handling(fn ->
      Bank |> where([b], b.status == "ACTIVE") |> Repo.all()
    end, context)
  end

  @doc """
  Lists banks by country with standardized return pattern.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_by_country(country) do
    context = %{action: :list_by_country, country: country}

    ErrorHandler.with_error_handling(fn ->
      Bank |> where([b], b.country == ^country) |> Repo.all()
    end, context)
  end

  @doc """
  Gets bank by code with standardized return pattern.
  Returns {:ok, bank} or {:error, reason}.
  """
  def get_by_code(code) do
    context = %{action: :get_by_code, code: code}

    ErrorHandler.with_error_handling(fn ->
      case Repo.get_by(Bank, code: code) do
        nil -> {:error, :not_found}
        bank -> {:ok, bank}
      end
    end, context)
  end

  @doc """
  Creates a bank with validation.
  Returns {:ok, bank} or {:error, reason}.
  """
  def create_bank(attrs) do
    context = %{action: :create_bank}

    ErrorHandler.with_error_handling(fn ->
      %Bank{}
      |> Bank.changeset(attrs)
      |> Repo.insert()
    end, context)
  end

  @doc """
  Updates a bank with validation.
  Returns {:ok, bank} or {:error, reason}.
  """
  def update_bank(bank, attrs) do
    context = %{action: :update_bank, bank_id: bank.id}

    ErrorHandler.with_error_handling(fn ->
      bank
      |> Bank.changeset(attrs)
      |> Repo.update()
    end, context)
  end
end

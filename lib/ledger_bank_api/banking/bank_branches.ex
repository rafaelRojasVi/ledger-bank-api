defmodule LedgerBankApi.Banking.BankBranches do
  @moduledoc """
  Enhanced business logic for bank branches with standardized return patterns.
  All functions return {:ok, data} or {:error, reason}.
  """
  alias LedgerBankApi.Banking.Schemas.BankBranch
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Banking.Behaviours.ErrorHandler
  import Ecto.Query
  use LedgerBankApi.CrudHelpers, schema: BankBranch

  @doc """
  Lists bank branches by bank ID with standardized return pattern.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_by_bank(bank_id) do
    context = %{action: :list_by_bank, bank_id: bank_id}

    ErrorHandler.with_error_handling(fn ->
      BankBranch
      |> where([bb], bb.bank_id == ^bank_id)
      |> preload(:bank)
      |> Repo.all()
    end, context)
  end

  @doc """
  Lists bank branches by country with standardized return pattern.
  Returns {:ok, list} or {:error, reason}.
  """
  def list_by_country(country) do
    context = %{action: :list_by_country, country: country}

    ErrorHandler.with_error_handling(fn ->
      BankBranch
      |> where([bb], bb.country == ^country)
      |> preload(:bank)
      |> Repo.all()
    end, context)
  end

  @doc """
  Gets bank branch by IBAN with standardized return pattern.
  Returns {:ok, branch} or {:error, reason}.
  """
  def get_by_iban(iban) do
    context = %{action: :get_by_iban, iban: iban}

    ErrorHandler.with_error_handling(fn ->
      case Repo.get_by(BankBranch, iban: iban) do
        nil -> {:error, :not_found}
        branch -> {:ok, Repo.preload(branch, :bank)}
      end
    end, context)
  end

  @doc """
  Creates a bank branch with validation.
  Returns {:ok, branch} or {:error, reason}.
  """
  def create_bank_branch(attrs) do
    context = %{action: :create_bank_branch, bank_id: attrs["bank_id"]}

    ErrorHandler.with_error_handling(fn ->
      %BankBranch{}
      |> BankBranch.changeset(attrs)
      |> Repo.insert()
    end, context)
  end

  @doc """
  Updates a bank branch with validation.
  Returns {:ok, branch} or {:error, reason}.
  """
  def update_bank_branch(branch, attrs) do
    context = %{action: :update_bank_branch, branch_id: branch.id}

    ErrorHandler.with_error_handling(fn ->
      branch
      |> BankBranch.changeset(attrs)
      |> Repo.update()
    end, context)
  end
end

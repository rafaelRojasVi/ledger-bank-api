defmodule LedgerBankApi.Financial.Schemas.Bank do
  @moduledoc """
  Ecto schema for banks. Represents a financial institution.
  """
  use LedgerBankApi.Core.SchemaHelpers

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :country,
             :logo_url,
             :api_endpoint,
             :status,
             :integration_module,
             :code,
             :inserted_at,
             :updated_at
           ]}

  schema "banks" do
    field(:name, :string)
    field(:country, :string)
    field(:logo_url, :string)
    field(:api_endpoint, :string)
    field(:status, :string, default: "ACTIVE")
    field(:integration_module, :string)
    field(:code, :string)

    has_many(:bank_branches, LedgerBankApi.Financial.Schemas.BankBranch)

    timestamps(type: :utc_datetime)
  end

  @fields [:name, :country, :logo_url, :api_endpoint, :status, :integration_module, :code]
  @required_fields [:name, :country, :code]

  def base_changeset(bank, attrs) do
    bank
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def changeset(bank, attrs) do
    bank
    |> base_changeset(attrs)
    |> unique_constraint(:name, name: :banks_name_index)
    |> unique_constraint(:code, name: :banks_code_index)
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE"])
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/)
    |> validate_length(:code, min: 3, max: 32)
    |> validate_country_code(:country)
    |> validate_name_length(:name)
    |> validate_url_format(:logo_url)
    |> validate_url_format(:api_endpoint)
    |> validate_integration_module()
    |> validate_name_uniqueness()
  end

  @doc """
  Builds a changeset for bank updates (without changing critical fields).
  """
  def update_changeset(bank, attrs) do
    bank
    |> cast(attrs, [:name, :logo_url, :api_endpoint, :status, :integration_module])
    |> validate_required([:name])
    |> validate_inclusion(:status, ["ACTIVE", "INACTIVE"])
    |> validate_name_length(:name)
    |> validate_url_format(:logo_url)
    |> validate_url_format(:api_endpoint)
    |> validate_integration_module()
    |> validate_name_uniqueness()
  end

  defp validate_integration_module(changeset) do
    integration_module = get_change(changeset, :integration_module)

    if is_nil(integration_module) or integration_module == "" do
      changeset
    else
      # Validate that the module string is a valid Elixir module name
      if String.match?(integration_module, ~r/^[A-Z][a-zA-Z0-9_]*(\.[A-Z][a-zA-Z0-9_]*)*$/) do
        changeset
      else
        add_error(
          changeset,
          :integration_module,
          "must be a valid Elixir module name (e.g., MyApp.Module)"
        )
      end
    end
  end

  defp validate_name_uniqueness(changeset) do
    name = get_change(changeset, :name)

    if is_nil(name) do
      changeset
    else
      # Check for common bank name patterns and validate
      if String.match?(name, ~r/^[a-zA-Z0-9\s\-&.,()]+$/) do
        changeset
      else
        add_error(
          changeset,
          :name,
          "contains invalid characters. Only letters, numbers, spaces, and common punctuation are allowed"
        )
      end
    end
  end

  @doc """
  Returns true if the bank is active.
  """
  def is_active?(%__MODULE__{status: "ACTIVE"}), do: true
  def is_active?(_), do: false

  @doc """
  Returns true if the bank has an integration module configured.
  """
  def has_integration?(%__MODULE__{integration_module: nil}), do: false
  def has_integration?(%__MODULE__{integration_module: ""}), do: false
  def has_integration?(_), do: true
end

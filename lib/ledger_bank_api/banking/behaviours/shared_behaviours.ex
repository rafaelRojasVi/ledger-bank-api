defmodule LedgerBankApi.Banking.Behaviours.SharedBehaviours do
  @moduledoc """
  Shared behaviour functions that are common across multiple behaviour modules.
  """

  @doc """
  Generic helper for struct creation/validation from params, validation function, and struct module.
  """
  def create_struct(params, validate_fun, struct_mod) do
    case validate_fun.(params) do
      {:ok, validated_params} -> {:ok, struct(struct_mod, validated_params)}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule LedgerBankApi.Banking.BankApiClient do
  @callback fetch_accounts(map()) :: {:ok, list()} | {:error, any()}
  @callback fetch_transactions(any(), map()) :: {:ok, list()} | {:error, any()}
  @callback fetch_balance(any(), map()) :: {:ok, map()} | {:error, any()}

  @doc """
  Generic mapping helper for bank integrations.
  - `data`: the external data (map or list of maps)
  - `mapping`: a map where keys are external field names and values are:
      - atom: the target field name
      - {atom, fun}: the target field name and a transformation function
  Returns a map or list of maps with the mapped fields.
  """
  def map_external(data, mapping) when is_list(data), do: Enum.map(data, &map_external(&1, mapping))
  def map_external(data, mapping) when is_map(data) do
    Enum.reduce(mapping, %{}, fn
      {ext_key, {target_key, fun}}, acc ->
        Map.put(acc, target_key, fun.(Map.get(data, ext_key)))
      {ext_key, target_key}, acc when is_atom(target_key) ->
        Map.put(acc, target_key, Map.get(data, ext_key))
    end)
  end
end

# lib/ledger_bank_api_web/resource_json.ex
defmodule LedgerBankApiWeb.ResourceJSON do
  @moduledoc """
  Injects standard `index/1`, `show/1`, and `one/1` helpers for JSON views.

  Usage — pass a `:resource` atom and the list of fields you want
  serialised:

      defmodule LedgerBankApiWeb.AccountJSON do
        use LedgerBankApiWeb.ResourceJSON,
            resource: :account,
            fields:   ~w(id institution type last4 balance)a
      end

  The macro generates:

  * `index(%{accounts: list})`   → `%{data: [...]}`  (plural key)
  * `show(%{account: item})`     → `%{data: %{…}}`   (singular key)
  * `one/1` helper that picks only the given fields.
  """

  @callback index(map()) :: map()
  @callback show(map())  :: map()

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour LedgerBankApiWeb.ResourceJSON

      @resource Keyword.fetch!(opts, :resource)            # :account
      @plural   :"#{@resource}s"                            # :accounts
      @fields   Keyword.fetch!(opts, :fields)               # [:id, …]

      #-------------- default implementations -----------------------------

      @impl true
      def index(%{@plural => list}) do
        %{data: Enum.map(list, &one/1)}
      end

      @impl true
      def show(%{@resource => item}) do
        %{data: one(item)}
      end

      # tiny helper – maps struct → map with selected fields
      defp one(struct) do
        struct
        |> Map.take(@fields)
      end

      # allow overrides
      defoverridable index: 1, show: 1
    end
  end
end

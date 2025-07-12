# lib/ledger_bank_api_web/resource_controller.ex
defmodule LedgerBankApiWeb.ResourceController do
  @moduledoc """
  Generic REST-style JSON controller with overridable defaults.

      defmodule LedgerBankApiWeb.AccountController do
        use LedgerBankApiWeb.ResourceController,
              context: LedgerBankApi.Banking,
              resource: :account
      end
  """

  @callback index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @callback show(Plug.Conn.t(), map())  :: Plug.Conn.t()

  # -------------------------------------------------------------------------
  defmacro __using__(opts) do
    # 1.  Compute everything **once** at compile-time so we don’t spend cycles
    #     converting strings ↔︎ atoms on every request.
    ctx      = Keyword.fetch!(opts, :context)
    resource = Keyword.fetch!(opts, :resource)          # e.g. :account
    plural   = String.to_atom("#{resource}s")           # e.g. :accounts

    quote bind_quoted: [ctx: ctx, resource: resource, plural: plural] do
      use LedgerBankApiWeb, :controller
      action_fallback LedgerBankApiWeb.FallbackController

      @behaviour LedgerBankApiWeb.ResourceController

      @ctx      ctx
      @resource resource
      @plural   plural

      # ---------- default /index ------------------------------------------
      @impl true
      def index(conn, _params) do
        list_fun = :"list_#{@plural}"      # :list_accounts / :list_transactions …
        data     = apply(@ctx, list_fun, [])
        render(conn, :index, %{@plural => data})        # ← **atom key**
      end

      # ---------- default /show -------------------------------------------
      @impl true
      def show(conn, %{"id" => id}) do
        get_fun = :"get_#{@resource}"      # :get_account / :get_transaction …
        case apply(@ctx, get_fun, [id]) do
          nil  -> {:error, :not_found}
          item -> render(conn, :show, %{@resource => item})   # ← **atom key**
        end
      end

      # Let individual controllers override either action if they need to
      defoverridable index: 2, show: 2
    end
  end
end

# lib/ledger_bank_api_web/resource_controller.ex
defmodule LedgerBankApiWeb.ResourceController do
  @moduledoc """
  Generic REST-y JSON controller with overridable defaults:

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
    quote bind_quoted: [opts: opts] do
      use LedgerBankApiWeb, :controller
      action_fallback LedgerBankApiWeb.FallbackController

      @behaviour LedgerBankApiWeb.ResourceController

      @ctx      Keyword.fetch!(opts, :context)
      @resource Keyword.fetch!(opts, :resource)       # :account, :transaction …
      @plural   "#{@resource}s"                       # "accounts" etc.

      # ---------- Default index / show -------------------------------------
      @impl true
      def index(conn, _params) do
        list_fun = :"list_#{@plural}"
        data     = apply(@ctx, list_fun, [])
        render(conn, :index, [{@plural, data}] |> Enum.into(%{}))
      end

      @impl true
      def show(conn, %{"id" => id}) do
        get_fun = :"get_#{@resource}"
        case apply(@ctx, get_fun, [id]) do
          nil  -> {:error, :not_found}
          item -> render(conn, :show, [{@resource, item}] |> Enum.into(%{}))
        end
      end

      # Let users override either action
      defoverridable index: 2, show: 2
    end
  end
end

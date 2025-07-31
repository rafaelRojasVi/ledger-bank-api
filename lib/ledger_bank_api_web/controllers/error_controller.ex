defmodule LedgerBankApiWeb.ErrorController do
  use LedgerBankApiWeb, :controller

  @doc """
  Handle 404 errors for non-existent routes.
  """
  def not_found(conn, _params) do
    conn
    |> put_status(404)
    |> json(%{
      error: %{
        type: :not_found,
        message: "Resource not found",
        code: 404
      }
    })
  end

  @doc """
  Handle 405 errors for unsupported HTTP methods.
  """
  def method_not_allowed(conn, _params) do
    conn
    |> put_status(405)
    |> json(%{
      error: %{
        type: :method_not_allowed,
        message: "Method not allowed",
        code: 405
      }
    })
  end
end

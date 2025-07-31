defmodule LedgerBankApiWeb.ErrorView do
  # use LedgerBankApiWeb, :view  # Removed, not needed

  def render("404.json", _assigns) do
    %{
      error: %{
        type: :not_found,
        message: "Resource not found",
        code: 404
      }
    }
  end

  def render("500.json", _assigns) do
    %{
      error: %{
        type: :internal_server_error,
        message: "Internal server error",
        code: 500
      }
    }
  end

  # Catch-all for other error codes
  def render(_template, _assigns) do
    %{
      error: %{
        type: :error,
        message: "An error occurred",
        code: 500
      }
    }
  end
end

defmodule LedgerBankApiWeb.Context do
  @moduledoc """
  GraphQL context for handling authentication and authorization.
  """

  require Logger

  alias LedgerBankApi.Accounts.Token

  def build_context(%{req_headers: headers}) do
    with ["Bearer " <> token] <- get_authorization_header(headers),
         {:ok, user} <- get_user_from_token(token) do
      %{current_user: user}
    else
      _ ->
        %{}
    end
  end

  def build_context(_conn) do
    %{}
  end

  # Private helper functions

  defp get_authorization_header(headers) do
    case Enum.find(headers, fn {key, _value} ->
      String.downcase(key) == "authorization"
    end) do
      {_key, value} -> [value]
      nil -> []
    end
  end

  defp get_user_from_token(token) do
    case Token.verify_access_token(token) do
      {:ok, %{"sub" => user_id}} ->
        case LedgerBankApi.Accounts.UserService.get_user(user_id) do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, :user_not_found}
        end

      {:error, _reason} = error ->
        error
    end
  end
end

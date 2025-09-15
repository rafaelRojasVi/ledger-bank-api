defmodule LedgerBankApiWeb.Plugs.Authenticate do
  @moduledoc """
  Plug for JWT authentication.
  Validates JWT tokens and assigns current_user and current_user_id to the connection.
  """

  import Plug.Conn
  import Phoenix.Controller


  def init(opts), do: opts

  def call(conn, _opts) do
    case get_auth_token(conn) do
      nil ->
        conn
        |> put_status(401)
        |> json(%{
          error: %{
            type: :unauthorized,
            message: "Unauthorized access",
            code: 401
          }
        })
        |> halt()

      token ->
        case authenticate_token(token) do
          {:ok, user} ->
            conn
            |> assign(:current_user, user)
            |> assign(:current_user_id, user.id)

          {:error, _reason} ->
            conn
            |> put_status(401)
            |> json(%{
              error: %{
                type: :unauthorized,
                message: "Unauthorized access",
                code: 401
              }
            })
            |> halt()
        end
    end
  end

  defp get_auth_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp authenticate_token(token) do
    with {:ok, claims} <- LedgerBankApi.Auth.verify_access_token(token),
         true <- claims["type"] == "access",
         false <- LedgerBankApi.Auth.is_token_expired?(token),
         user_id when is_binary(user_id) <- claims["sub"],
         {:ok, %LedgerBankApi.Users.User{} = user} <- LedgerBankApi.Users.get_user(user_id),
         true <- user.status == "ACTIVE" do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, "Token expired"}
      nil -> {:error, "User not found"}
      _ -> {:error, "Invalid token"}
    end
  end
end

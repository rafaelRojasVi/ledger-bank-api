defmodule LedgerBankApiWeb.UserSocket do
  @moduledoc """
  Phoenix Socket for authenticated user connections.

  Handles WebSocket authentication and channel routing for real-time features.
  """

  use Phoenix.Socket
  require Logger

  alias LedgerBankApi.Accounts.Token

  ## Channels
  channel "payment:*", LedgerBankApiWeb.PaymentChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_token(token) do
      {:ok, user} ->
        Logger.info("User #{user.id} connected via WebSocket")
        {:ok, assign(socket, :current_user, user)}

      {:error, reason} ->
        Logger.warning("WebSocket connection failed: #{inspect(reason)}")
        :error
    end
  end

  def connect(%{"jwt" => jwt_token}, socket, _connect_info) do
    case verify_jwt_token(jwt_token) do
      {:ok, user} ->
        Logger.info("User #{user.id} connected via WebSocket with JWT")
        {:ok, assign(socket, :current_user, user)}

      {:error, reason} ->
        Logger.warning("WebSocket JWT connection failed: #{inspect(reason)}")
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    Logger.warning("WebSocket connection attempted without authentication")
    :error
  end

  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.LedgerBankApiWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket) do
    if user = socket.assigns[:current_user] do
      "user_socket:#{user.id}"
    else
      nil
    end
  end

  # Private helper functions

  defp verify_token(token) when is_binary(token) do
    # For WebSocket connections, we might use a different token format
    # This could be a session token, API token, or JWT
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

  defp verify_jwt_token(jwt_token) when is_binary(jwt_token) do
    case Token.verify_access_token(jwt_token) do
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

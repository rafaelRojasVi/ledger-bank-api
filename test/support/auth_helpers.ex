defmodule LedgerBankApiWeb.AuthHelpers do
  @moduledoc """
  Test helpers for authentication.
  Provides functions to create users, generate tokens, and authenticate requests.
  """

  import Plug.Conn, only: [put_req_header: 3]
  alias LedgerBankApi.UsersFixtures
  alias LedgerBankApi.Auth.JWT

  @doc """
  Creates a test user with the given attributes.
  """
  def create_test_user(attrs \\ %{}) do
    UsersFixtures.user_fixture(attrs)
  end

  @doc """
  Creates a test admin user.
  """
  def create_test_admin(attrs \\ %{}) do
    UsersFixtures.admin_user_fixture(attrs)
  end

  @doc """
  Generates an access token for a user.
  """
  def generate_access_token(user) do
    JWT.generate_access_token(user)
  end

  @doc """
  Generates a refresh token for a user.
  """
  def generate_refresh_token(user) do
    JWT.generate_refresh_token(user)
  end

  @doc """
  Adds authentication header to a connection.
  """
  def authenticate_conn(conn, user) do
    case generate_access_token(user) do
      {:ok, access_token} ->
        put_req_header(conn, "authorization", "Bearer #{access_token}")
      _ ->
        conn
    end
  end

  @doc """
  Creates and authenticates a user in one step.
  Returns {user, access_token, conn}.
  """
  def setup_authenticated_user(conn, attrs \\ %{}) do
    user = create_test_user(attrs)
    {:ok, access_token} = generate_access_token(user)
    conn = authenticate_conn(conn, user)
    {user, access_token, conn}
  end

  @doc """
  Creates and authenticates an admin user in one step.
  Returns {user, access_token, conn}.
  """
  def setup_authenticated_admin(conn, attrs \\ %{}) do
    user = create_test_admin(attrs)
    {:ok, access_token} = generate_access_token(user)
    conn = authenticate_conn(conn, user)
    {user, access_token, conn}
  end

  @doc """
  Creates multiple test users for testing scenarios.
  """
  def create_test_users(count, attrs \\ %{}) do
    Enum.map(1..count, fn i ->
      user_attrs = Map.merge(attrs, %{
        email: "user#{i}@example.com",
        full_name: "User #{i}"
      })
      create_test_user(user_attrs)
    end)
  end

  @doc """
  Creates a user with a specific role for testing role-based scenarios.
  """
  def create_user_with_role(role, attrs \\ %{}) do
    user_attrs = Map.merge(attrs, %{role: role})
    create_test_user(user_attrs)
  end
end

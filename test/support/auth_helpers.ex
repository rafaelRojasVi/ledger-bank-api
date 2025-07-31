defmodule LedgerBankApiWeb.AuthHelpers do
  @moduledoc """
  Test helpers for authentication.
  Provides functions to create users, generate tokens, and authenticate requests.
  """

  import LedgerBankApi.Users.Context
  import Plug.Conn, only: [put_req_header: 3]

  @doc """
  Creates a test user with the given attributes.
  """
  def create_test_user(attrs \\ %{}) do
    default_attrs = %{
      "email" => "test#{System.unique_integer()}@example.com",
      "full_name" => "Test User",
      "password" => "password123",
      "role" => "user"
    }

    # Convert atom keys to string keys to match create_user expectations
    attrs = attrs
            |> Enum.map(fn {k, v} -> {if(is_atom(k), do: Atom.to_string(k), else: k), v} end)
            |> Enum.into(%{})

    attrs = Map.merge(default_attrs, attrs)
    create_user(attrs)
  end

  @doc """
  Creates a test admin user.
  """
  def create_test_admin(attrs \\ %{}) do
    default_attrs = %{
      "email" => "test#{System.unique_integer()}@example.com",
      "full_name" => "Test User",
      "password" => "password123",
      "role" => "admin"
    }

    # Convert atom keys to string keys to match create_user expectations
    attrs = attrs
            |> Enum.map(fn {k, v} -> {if(is_atom(k), do: Atom.to_string(k), else: k), v} end)
            |> Enum.into(%{})

    attrs = Map.merge(default_attrs, attrs)
    create_user(attrs)
  end

  @doc """
  Authenticates a user and returns access token.
  """
  def authenticate_user(user, password \\ "password123") do
    case login_user(user.email, password) do
      {:ok, _user, access_token, _refresh_token} -> {:ok, access_token}
      error -> error
    end
  end

  @doc """
  Authenticates a user and returns both access and refresh tokens.
  """
  def authenticate_user_with_tokens(user, password \\ "password123") do
    case login_user(user.email, password) do
      {:ok, _user, access_token, refresh_token} -> {:ok, access_token, refresh_token}
      error -> error
    end
  end

  @doc """
  Adds authentication header to a connection.
  """
  def authenticate_conn(conn, user, password \\ "password123") do
    case authenticate_user(user, password) do
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
    {:ok, user} = create_test_user(attrs)
    {:ok, access_token} = authenticate_user(user)
    conn = authenticate_conn(conn, user)
    {user, access_token, conn}
  end

  @doc """
  Creates and authenticates an admin user in one step.
  Returns {user, access_token, conn}.
  """
  def setup_authenticated_admin(conn, attrs \\ %{}) do
    {:ok, user} = create_test_admin(attrs)
    {:ok, access_token} = authenticate_user(user)
    conn = authenticate_conn(conn, user)
    {user, access_token, conn}
  end

  @doc """
  Creates multiple test users for testing scenarios.
  """
  def create_test_users(count, attrs \\ %{}) do
    Enum.map(1..count, fn i ->
      user_attrs = Map.merge(attrs, %{
        "email" => "user#{i}@example.com",
        "full_name" => "User #{i}"
      })
      {:ok, user} = create_test_user(user_attrs)
      user
    end)
  end

  @doc """
  Suspends a user for testing suspended user scenarios.
  """
  def suspend_user_for_test(user) do
    suspend_user(user)
  end

  @doc """
  Activates a user for testing user activation scenarios.
  """
  def activate_user_for_test(user) do
    activate_user(user)
  end

  @doc """
  Creates a user with a specific role for testing role-based scenarios.
  """
  def create_user_with_role(role, attrs \\ %{}) do
    default_attrs = %{
      "email" => "test#{System.unique_integer()}@example.com",
      "full_name" => "Test User",
      "password" => "password123",
      "role" => role
    }

    # Convert atom keys to string keys to match create_user expectations
    attrs = attrs
            |> Enum.map(fn {k, v} -> {if(is_atom(k), do: Atom.to_string(k), else: k), v} end)
            |> Enum.into(%{})

    attrs = Map.merge(default_attrs, attrs)
    create_user(attrs)
  end
end

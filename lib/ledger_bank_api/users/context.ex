defmodule LedgerBankApi.Users.Context do
  @moduledoc """
  The Users context for LedgerBankApi.
  Provides functions for managing application users, including creation, updates, and status changes.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Users.User

  use LedgerBankApi.CrudHelpers, schema: User

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Returns list of active users.
  """
  def list_active_users do
    User
    |> where(status: "ACTIVE")
    |> Repo.all()
  end

  @doc """
  Returns list of suspended users.
  """
  def list_suspended_users do
    User
    |> where(status: "SUSPENDED")
    |> Repo.all()
  end

  @doc """
  Suspends a user.
  """
  def suspend_user(%User{} = user) do
    __MODULE__.update(user, %{status: "SUSPENDED"})
  end

  @doc """
  Activates a user.
  """
  def activate_user(%User{} = user) do
    __MODULE__.update(user, %{status: "ACTIVE"})
  end
end

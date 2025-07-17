defmodule LedgerBankApi.Users do
  @moduledoc """
  The Users context for LedgerBankApi.
  Provides functions for managing application users, including creation, updates, and status changes.
  """

  import Ecto.Query, warn: false
  alias LedgerBankApi.Repo

  alias LedgerBankApi.Users.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
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
    update_user(user, %{status: "SUSPENDED"})
  end

  @doc """
  Activates a user.
  """
  def activate_user(%User{} = user) do
    update_user(user, %{status: "ACTIVE"})
  end
end

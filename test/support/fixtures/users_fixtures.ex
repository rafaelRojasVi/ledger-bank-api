defmodule LedgerBankApi.UsersFixtures do
  alias LedgerBankApi.Repo
  alias LedgerBankApi.Accounts.Schemas.User

  def user_fixture(attrs \\ %{}) do
    base = %{
      email: "user_#{System.unique_integer()}@ex.com",
      full_name: "User Test",
      role: "user",
      password: "ValidPassword123!",
      password_confirmation: "ValidPassword123!"
    }

    {:ok, user} =
      %User{} |> User.changeset(Map.merge(base, attrs)) |> Repo.insert()

    user
  end

  def admin_user_fixture(attrs \\ %{}) do
    user_fixture(Map.merge(%{role: "admin"}, attrs))
  end

  def user_with_password_fixture(password, attrs \\ %{}) do
    user_fixture(
      Map.merge(
        %{
          password: password,
          password_confirmation: password
        },
        attrs
      )
    )
  end
end

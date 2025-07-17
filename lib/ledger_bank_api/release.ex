defmodule LedgerBankApi.Release do
  @moduledoc """
  Helpers executed inside the OTP release for database migrations and app loading.
  Used for running migrations and starting dependencies in production releases.
  """

  @app :ledger_bank_api

  # ---------- public API -------------------------------------------------
  @doc """
  Runs all Ecto migrations for the application.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      # Path where migrations live **inside** the release
      path = Application.app_dir(@app, "priv/repo/migrations")
      IO.puts("📦  Running Ecto migrations for #{inspect(repo)} …")
      Ecto.Migrator.run(repo, path, :up, all: true)
    end

    IO.puts("✅  Migrations finished.")
  end

  # ---------- helpers ----------------------------------------------------
  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app do
    # Load runtime-config
    Application.load(@app)

    # 1.   Ensure all apps LedgerBankApi depends on are started
    for app <- Application.spec(@app, :applications) do
      {:ok, _} = Application.ensure_all_started(app)
    end

    # 2.   Start each Ecto repo **temporarily** (not under a supervisor)
    for repo <- repos() do
      {:ok, _pid} = repo.start_link(pool_size: 2, log: false)
    end
  end
end

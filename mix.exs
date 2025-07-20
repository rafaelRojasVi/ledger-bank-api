defmodule LedgerBankApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ledger_bank_api,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test:paginated": :test,
        "test:filterable": :test,
        "test:sortable": :test,
        "test:error-handler": :test,
        "test:behaviours": :test,
        "test:controllers": :test,
        "test:integration": :test,
        "test:unit": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {LedgerBankApi.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.7"},
      {:joken, "~> 2.6"},
      {:oban, "~> 2.18"},
      {:mimic, "~> 1.7", only: :test},
      {:req, "~> 0.5.10"},
      {:argon2_elixir, "~> 3.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # Test aliases for easier test running
      "test:paginated": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api/behaviours/paginated/"],
      "test:filterable": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api/behaviours/filterable/"],
      "test:sortable": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api/behaviours/sortable/"],
      "test:error-handler": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api/behaviours/error_handler/"],
      "test:behaviours": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api/behaviours/"],
      "test:controllers": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api_web/controllers/"],
      "test:integration": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api/behaviours/integration_test.exs"],
      "test:unit": ["ecto.create --quiet", "ecto.migrate --quiet", "test test/ledger_bank_api/"]
    ]
  end
end

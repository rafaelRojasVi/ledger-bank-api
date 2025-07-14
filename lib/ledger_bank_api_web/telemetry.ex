defmodule LedgerBankApiWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("ledger_bank_api.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("ledger_bank_api.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("ledger_bank_api.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("ledger_bank_api.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("ledger_bank_api.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Custom Banking Metrics
      summary("ledger_bank_api.banking.list_accounts.duration",
        unit: {:native, :millisecond},
        description: "Time to list accounts"
      ),
      summary("ledger_bank_api.banking.get_account.duration",
        unit: {:native, :millisecond},
        description: "Time to get single account"
      ),
      summary("ledger_bank_api.banking.list_transactions.duration",
        unit: {:native, :millisecond},
        description: "Time to list transactions"
      ),

      # Fetcher Metrics
      summary("ledger_bank_api.fetcher.fetch_all.duration",
        unit: {:native, :millisecond},
        description: "Time to fetch all external data"
      ),
      counter("ledger_bank_api.fetcher.fetch_all.success_count",
        description: "Number of successful external API calls"
      ),
      counter("ledger_bank_api.fetcher.fetch_all.error_count",
        description: "Number of failed external API calls"
      ),

      # External API Metrics
      summary("ledger_bank_api.external.bank_client.request.duration",
        tags: [:endpoint],
        unit: {:native, :millisecond},
        description: "External API request duration"
      ),
      counter("ledger_bank_api.external.bank_client.request.count",
        tags: [:endpoint, :status],
        description: "External API request count by status"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {LedgerBankApiWeb, :count_users, []}
    ]
  end
end

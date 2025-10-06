defmodule LedgerBankApi.ObanCase do
  use ExUnit.CaseTemplate
  use Oban.Testing, repo: LedgerBankApi.Repo

  using do
    quote do
      import Oban.Testing
      import Ecto.Query
      alias LedgerBankApi.Repo
      alias LedgerBankApi.Financial.Workers.{BankSyncWorker, PaymentWorker}

      # Enhanced job assertion helpers
      def assert_job_enqueued(opts) do
        worker = Keyword.get(opts, :worker)
        queue = Keyword.get(opts, :queue)
        args = Keyword.get(opts, :args)
        priority = Keyword.get(opts, :priority)

        query = from j in Oban.Job,
          where: j.worker == ^to_string(worker),
          where: j.state in ["available", "scheduled"]

        query = if queue, do: from(j in query, where: j.queue == ^to_string(queue)), else: query
        query = if args, do: from(j in query, where: fragment("? @> ?", j.args, ^args)), else: query
        query = if priority, do: from(j in query, where: j.priority == ^priority), else: query

        jobs = Repo.all(query)
        assert length(jobs) > 0, "Expected job to be enqueued for #{worker} with opts: #{inspect(opts)}"
        List.first(jobs)
      end

      def assert_job_not_enqueued(opts) do
        worker = Keyword.get(opts, :worker)
        queue = Keyword.get(opts, :queue)
        args = Keyword.get(opts, :args)

        query = from j in Oban.Job,
          where: j.worker == ^to_string(worker),
          where: j.state in ["available", "scheduled"]

        query = if queue, do: from(j in query, where: j.queue == ^to_string(queue)), else: query
        query = if args, do: from(j in query, where: fragment("? @> ?", j.args, ^args)), else: query

        jobs = Repo.all(query)
        assert length(jobs) == 0, "Expected no job to be enqueued for #{worker} with opts: #{inspect(opts)}"
      end

      def get_job_count(opts) do
        worker = Keyword.get(opts, :worker)
        queue = Keyword.get(opts, :queue)
        state = Keyword.get(opts, :state)

        query = from j in Oban.Job,
          where: j.worker == ^to_string(worker)

        query = if queue, do: from(j in query, where: j.queue == ^to_string(queue)), else: query
        query = if state, do: from(j in query, where: j.state == ^state), else: query

        Repo.aggregate(query, :count, :id)
      end

      def clear_all_jobs do
        Repo.delete_all(Oban.Job)
      end

      # Telemetry helpers for testing job execution order
      def with_telemetry_handler(event_name, handler_fun, fun) do
        ref = make_ref()
        :telemetry.attach(
          {event_name, ref},
          [:oban, :job, :start],
          handler_fun,
          nil
        )

        try do
          fun.()
        after
          :telemetry.detach({event_name, ref})
        end
      end

      def wait_for_job_completion(timeout \\ 1000) do
        Process.sleep(timeout)
      end
    end
  end

  setup do
    # Check out database connection for this test process
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LedgerBankApi.Repo)

    # Clear any existing jobs before each test
    LedgerBankApi.Repo.delete_all(Oban.Job)
    :ok
  end
end

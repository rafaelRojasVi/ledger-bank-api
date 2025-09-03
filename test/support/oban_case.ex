defmodule LedgerBankApi.ObanCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # For manual testing mode, we'll implement our own Oban testing helpers
      def assert_enqueued(opts) do
        # Check if a job was enqueued by looking at the Oban.Job table
        worker = Keyword.get(opts, :worker)
        args = Keyword.get(opts, :args)

        query = from j in Oban.Job,
          where: j.worker == ^to_string(worker),
          where: j.state in ["available", "scheduled"]

        if args do
          # Simple args matching - in production you'd want more sophisticated matching
          query = from j in query, where: fragment("? @> ?", j.args, ^args)
        end

        jobs = LedgerBankApi.Repo.all(query)
        assert length(jobs) > 0, "Expected job to be enqueued for #{worker}"
      end

      def perform_job(worker, args) do
        # For manual testing, we'll call the worker's perform function directly
        job = %Oban.Job{
          id: Ecto.UUID.generate(),
          args: args,
          worker: to_string(worker),
          state: "available"
        }

        case worker.perform(job) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
          :ok -> :ok
          other -> other
        end
      end
    end
  end
end

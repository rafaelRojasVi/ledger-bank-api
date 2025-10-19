defmodule LedgerBankApi.Repo.Migrations.AddObanJobsArgsIndex do
  use Ecto.Migration

  def up do
    # Create a B-tree index on the extracted payment_id for efficient lookups
    # This will significantly improve performance for queries like:
    # WHERE args->>'payment_id' = 'some-uuid'
    create index(:oban_jobs, ["(args->>'payment_id')"],
      name: :oban_jobs_payment_id_index
    )
  end

  def down do
    drop index(:oban_jobs, [:oban_jobs_payment_id_index])
  end
end

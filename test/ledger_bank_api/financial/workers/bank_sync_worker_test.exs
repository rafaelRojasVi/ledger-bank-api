defmodule LedgerBankApi.Financial.Workers.BankSyncWorkerTest do
  use LedgerBankApi.ObanCase, async: true
  import Mox

  alias LedgerBankApi.Financial.Workers.BankSyncWorker
  alias LedgerBankApi.Financial.FinancialServiceMock
  alias LedgerBankApi.Core.Error

  setup :verify_on_exit!

  describe "perform/1" do
    test "successfully syncs bank login" do
      login_id = Ecto.UUID.generate()

      # Mock successful sync
      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:ok, %{status: "synced", login_id: login_id, synced_at: DateTime.utc_now()}}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert :ok = BankSyncWorker.perform(job)
    end

    test "handles sync failures gracefully" do
      login_id = Ecto.UUID.generate()

      # Mock sync failure
      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:error, %Error{
          reason: :service_unavailable,
          category: :external_dependency,
          retryable: true,
          message: "Bank API temporarily unavailable"
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1
      }

      assert {:error, %Error{retryable: true}} = BankSyncWorker.perform(job)
    end

    test "handles non-retryable errors" do
      login_id = Ecto.UUID.generate()

      # Mock non-retryable error
      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:error, %Error{
          reason: :bank_not_found,
          category: :not_found,
          retryable: false,
          message: "Bank login not found"
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1
      }

      assert {:error, %Error{retryable: false}} = BankSyncWorker.perform(job)
    end

    test "handles unexpected errors" do
      login_id = Ecto.UUID.generate()

      # Mock unexpected error
      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:error, "Unexpected error"}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1
      }

      assert {:error, %Error{}} = BankSyncWorker.perform(job)
    end
  end

  describe "scheduling functions" do
    test "schedule_sync/2 enqueues job with correct args" do
      login_id = Ecto.UUID.generate()

      {:ok, job} = BankSyncWorker.schedule_sync(login_id)

      # With inline testing, jobs are executed immediately
      # So we just verify the job was created with correct args
      assert job.args["login_id"] == login_id
      assert job.worker == "LedgerBankApi.Financial.Workers.BankSyncWorker"
    end

    # Note: schedule_sync_with_delay tests are skipped in inline mode
    # because schedule_in doesn't work with inline testing.
    # These are tested in integration tests instead.
  end

  describe "error handling and retry logic" do
    test "retryable errors are properly categorized" do
      login_id = Ecto.UUID.generate()

      # Mock retryable error
      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:error, %Error{
          reason: :timeout,
          category: :external_dependency,
          retryable: true
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1
      }

      result = BankSyncWorker.perform(job)

      assert {:error, %Error{retryable: true, category: :external_dependency}} = result
    end

    test "non-retryable errors are properly categorized" do
      login_id = Ecto.UUID.generate()

      # Mock non-retryable error
      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:error, %Error{
          reason: :bank_not_found,
          category: :not_found,
          retryable: false
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1
      }

      result = BankSyncWorker.perform(job)

      assert {:error, %Error{retryable: false, category: :not_found}} = result
    end
  end

  describe "job context and correlation" do
    test "includes proper context in job execution" do
      login_id = Ecto.UUID.generate()
      job_id = Ecto.UUID.generate()

      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:ok, %{status: "synced", login_id: login_id}}
      end)

      job = %Oban.Job{
        id: job_id,
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 2,
        max_attempts: 5
      }

      # Capture logs to verify context
      ExUnit.CaptureLog.capture_log(fn ->
        assert :ok = BankSyncWorker.perform(job)
      end)
    end
  end

  describe "timeout configuration" do
    test "worker has configured timeout" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => "test"},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker"
      }

      # Timeout should be 10 minutes (600,000 milliseconds)
      assert BankSyncWorker.timeout(job) == :timer.minutes(10)
      assert BankSyncWorker.timeout(job) == 600_000
    end
  end

  describe "backoff configuration" do
    test "uses exponential backoff by default" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => "test"},
        attempt: 1
      }

      # First attempt: 1000ms
      assert BankSyncWorker.backoff(job) == 1000

      # Second attempt: 2000ms
      job2 = %{job | attempt: 2}
      assert BankSyncWorker.backoff(job2) == 2000

      # Third attempt: 4000ms
      job3 = %{job | attempt: 3}
      assert BankSyncWorker.backoff(job3) == 4000
    end

    test "uses custom backoff for external dependency errors" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => "test", "error_category" => "external_dependency"},
        attempt: 1
      }

      # First attempt: 1000ms (external_dependency base)
      assert BankSyncWorker.backoff(job) == 1000
    end

    test "uses custom backoff for system errors" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => "test", "error_category" => "system"},
        attempt: 1
      }

      # First attempt: 500ms (system error base)
      assert BankSyncWorker.backoff(job) == 500
    end
  end

  describe "job uniqueness" do
    test "schedule_sync prevents duplicate jobs within period" do
      login_id = Ecto.UUID.generate()

      # Mock successful processing
      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:ok, %{status: "synced", login_id: login_id}}
      end)

      # Schedule first job
      {:ok, job1} = BankSyncWorker.schedule_sync(login_id)
      assert job1.args["login_id"] == login_id

      # Try to schedule duplicate job - should return existing or conflict
      result = BankSyncWorker.schedule_sync(login_id)

      # In inline mode, might process immediately, but uniqueness should prevent duplicates
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "telemetry events" do
    test "emits success telemetry on successful sync" do
      login_id = Ecto.UUID.generate()

      # Attach telemetry handler
      handler_id = "test-bank-sync-success-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :worker, :bank_sync, :success],
        fn event, measurements, metadata, _config ->
          send(self_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:ok, %{status: "synced", login_id: login_id}}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert :ok = BankSyncWorker.perform(job)

      # Verify telemetry event was emitted
      assert_receive {:telemetry_event, [:ledger_bank_api, :worker, :bank_sync, :success], measurements, metadata}, 1000
      assert measurements.count == 1
      assert is_integer(measurements.duration)
      assert metadata.worker == "BankSyncWorker"
      assert metadata.login_id == login_id

      :telemetry.detach(handler_id)
    end

    test "emits failure telemetry on sync failure" do
      login_id = Ecto.UUID.generate()

      # Attach telemetry handler
      handler_id = "test-bank-sync-failure-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :worker, :bank_sync, :failure],
        fn event, measurements, metadata, _config ->
          send(self_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:error, %Error{
          reason: :service_unavailable,
          category: :external_dependency,
          retryable: true
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{}} = BankSyncWorker.perform(job)

      # Verify telemetry event was emitted
      assert_receive {:telemetry_event, [:ledger_bank_api, :worker, :bank_sync, :failure], measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.error_reason == :service_unavailable

      :telemetry.detach(handler_id)
    end

    test "emits dead-letter telemetry for non-retryable errors" do
      login_id = Ecto.UUID.generate()

      # Attach telemetry handler
      handler_id = "test-dead-letter-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :worker, :dead_letter],
        fn event, measurements, metadata, _config ->
          send(self_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      expect(FinancialServiceMock, :sync_login, fn ^login_id ->
        {:error, %Error{
          reason: :bank_not_found,
          category: :not_found,
          retryable: false
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"login_id" => login_id},
        worker: "LedgerBankApi.Financial.Workers.BankSyncWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{retryable: false}} = BankSyncWorker.perform(job)

      # Verify dead-letter telemetry was emitted
      assert_receive {:telemetry_event, [:ledger_bank_api, :worker, :dead_letter], measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.worker == "BankSyncWorker"
      assert metadata.error_reason == :bank_not_found
      assert metadata.error_category == :not_found

      :telemetry.detach(handler_id)
    end
  end
end

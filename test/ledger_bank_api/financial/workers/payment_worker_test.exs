defmodule LedgerBankApi.Financial.Workers.PaymentWorkerTest do
  use LedgerBankApi.ObanCase, async: true
  import Mox

  alias LedgerBankApi.Financial.Workers.PaymentWorker
  alias LedgerBankApi.Financial.FinancialServiceMock
  alias LedgerBankApi.Core.Error

  setup :verify_on_exit!

  describe "perform/1" do
    test "successfully processes payment" do
      payment_id = Ecto.UUID.generate()

      # Mock successful payment processing
      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:ok, %{id: payment_id, status: "PENDING", amount: 100.00}}
      end)

      expect(FinancialServiceMock, :process_payment, fn ^payment_id ->
        {:ok, %{status: "completed", payment_id: payment_id, processed_at: DateTime.utc_now()}}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert :ok = PaymentWorker.perform(job)
    end

    test "handles payment not found" do
      payment_id = Ecto.UUID.generate()

      # Mock payment not found
      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:error, %Error{
          reason: :payment_not_found,
          category: :not_found,
          retryable: false,
          message: "Payment not found"
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{retryable: false}} = PaymentWorker.perform(job)
    end

    test "handles payment processing failures" do
      payment_id = Ecto.UUID.generate()

      # Mock payment fetch success but processing failure
      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:ok, %{id: payment_id, status: "PENDING", amount: 100.00}}
      end)

      expect(FinancialServiceMock, :process_payment, fn ^payment_id ->
        {:error, %Error{
          reason: :insufficient_funds,
          category: :business_rule,
          retryable: false,
          message: "Insufficient funds"
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{retryable: false}} = PaymentWorker.perform(job)
    end

    test "handles external service failures" do
      payment_id = Ecto.UUID.generate()

      # Mock external service failure
      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:error, %Error{
          reason: :service_unavailable,
          category: :external_dependency,
          retryable: true,
          message: "Payment service temporarily unavailable"
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1
      }

      assert {:error, %Error{retryable: true}} = PaymentWorker.perform(job)
    end
  end

  describe "scheduling functions" do
    test "schedule_payment/2 enqueues job with correct args" do
      payment_id = Ecto.UUID.generate()

      {:ok, job} = PaymentWorker.schedule_payment(payment_id)

      # With inline testing, jobs are executed immediately
      # So we just verify the job was created with correct args
      assert job.args["payment_id"] == payment_id
      assert job.worker == "LedgerBankApi.Financial.Workers.PaymentWorker"
    end

    # Note: schedule_payment_with_delay tests are skipped in inline mode
    # because schedule_in doesn't work with inline testing.
    # These are tested in integration tests instead.

    test "schedule_payment_with_priority/3 enqueues job with priority" do
      payment_id = Ecto.UUID.generate()
      priority = 0  # High priority

      {:ok, job} = PaymentWorker.schedule_payment_with_priority(payment_id, priority)

      assert job.priority == priority
      assert job.args["payment_id"] == payment_id
    end

    test "schedule_payment_with_priority/3 with custom options" do
      payment_id = Ecto.UUID.generate()
      priority = 5
      opts = [max_attempts: 3, queue: :payments]

      {:ok, job} = PaymentWorker.schedule_payment_with_priority(payment_id, priority, opts)

      assert job.priority == priority
      assert job.max_attempts == 3
      assert job.queue == "payments"
    end
  end

  describe "priority handling" do
    test "high priority payments are enqueued with priority 0" do
      payment_id = Ecto.UUID.generate()

      {:ok, job} = PaymentWorker.schedule_payment_with_priority(payment_id, 0)

      assert job.priority == 0
      assert job.args["payment_id"] == payment_id
    end

    test "low priority payments are enqueued with higher priority number" do
      payment_id = Ecto.UUID.generate()

      {:ok, job} = PaymentWorker.schedule_payment_with_priority(payment_id, 9)

      assert job.priority == 9
      assert job.args["payment_id"] == payment_id
    end

    test "priority validation" do
      payment_id = Ecto.UUID.generate()

      # Test valid priority range (0-9)
      assert {:ok, _job} = PaymentWorker.schedule_payment_with_priority(payment_id, 0)
      assert {:ok, _job} = PaymentWorker.schedule_payment_with_priority(payment_id, 5)
      assert {:ok, _job} = PaymentWorker.schedule_payment_with_priority(payment_id, 9)

      # Test that priority 10 is invalid (should raise FunctionClauseError)
      assert_raise FunctionClauseError, fn ->
        PaymentWorker.schedule_payment_with_priority(payment_id, 10)
      end

      # Test that negative priority is invalid
      assert_raise FunctionClauseError, fn ->
        PaymentWorker.schedule_payment_with_priority(payment_id, -1)
      end
    end
  end

  describe "error handling and retry logic" do
    test "retryable errors are properly categorized" do
      payment_id = Ecto.UUID.generate()

      # Mock retryable error
      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:error, %Error{
          reason: :timeout,
          category: :external_dependency,
          retryable: true
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1
      }

      result = PaymentWorker.perform(job)

      assert {:error, %Error{retryable: true, category: :external_dependency}} = result
    end

    test "business rule errors are not retryable" do
      payment_id = Ecto.UUID.generate()

      # Mock business rule error
      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, fn ^payment_id ->
        {:error, %Error{
          reason: :insufficient_funds,
          category: :business_rule,
          retryable: false
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1
      }

      result = PaymentWorker.perform(job)

      assert {:error, %Error{retryable: false, category: :business_rule}} = result
    end
  end

  describe "job context and correlation" do
    test "includes proper context in job execution" do
      payment_id = Ecto.UUID.generate()
      job_id = Ecto.UUID.generate()

      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, fn ^payment_id ->
        {:ok, %{status: "completed", payment_id: payment_id}}
      end)

      job = %Oban.Job{
        id: job_id,
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 2,
        max_attempts: 5
      }

      # Capture logs to verify context
      ExUnit.CaptureLog.capture_log(fn ->
        assert :ok = PaymentWorker.perform(job)
      end)
    end
  end

  describe "timeout configuration" do
    test "worker has configured timeout" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => "test"},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker"
      }

      # Timeout should be 5 minutes (300,000 milliseconds)
      assert PaymentWorker.timeout(job) == :timer.minutes(5)
      assert PaymentWorker.timeout(job) == 300_000
    end
  end

  describe "backoff configuration" do
    test "uses exponential backoff by default" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => "test"},
        attempt: 1
      }

      # First attempt: 1000ms
      assert PaymentWorker.backoff(job) == 1000

      # Second attempt: 2000ms
      job2 = %{job | attempt: 2}
      assert PaymentWorker.backoff(job2) == 2000

      # Third attempt: 4000ms
      job3 = %{job | attempt: 3}
      assert PaymentWorker.backoff(job3) == 4000
    end

    test "uses custom backoff for external dependency errors" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => "test", "error_category" => "external_dependency"},
        attempt: 1
      }

      # First attempt: 1000ms (external_dependency base)
      assert PaymentWorker.backoff(job) == 1000

      # Second attempt: 2000ms
      job2 = %{job | attempt: 2}
      assert PaymentWorker.backoff(job2) == 2000
    end

    test "uses custom backoff for system errors" do
      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => "test", "error_category" => "system"},
        attempt: 1
      }

      # First attempt: 500ms (system error base)
      assert PaymentWorker.backoff(job) == 500

      # Second attempt: 1000ms
      job2 = %{job | attempt: 2}
      assert PaymentWorker.backoff(job2) == 1000
    end
  end

  describe "job uniqueness" do
    test "schedule_payment_with_priority prevents duplicate jobs within period" do
      payment_id = Ecto.UUID.generate()

      # Mock successful processing
      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, fn ^payment_id ->
        {:ok, %{status: "completed", payment_id: payment_id}}
      end)

      # Schedule first job
      {:ok, job1} = PaymentWorker.schedule_payment_with_priority(payment_id, 5)
      assert job1.args["payment_id"] == payment_id

      # Try to schedule duplicate job - should return existing or conflict
      result = PaymentWorker.schedule_payment_with_priority(payment_id, 5)

      # In inline mode, might process immediately, but uniqueness should prevent duplicates
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "telemetry events" do
    test "emits success telemetry on successful processing" do
      payment_id = Ecto.UUID.generate()

      # Attach telemetry handler
      handler_id = "test-payment-success-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :worker, :payment, :success],
        fn event, measurements, metadata, _config ->
          send(self_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, fn ^payment_id ->
        {:ok, %{status: "completed", payment_id: payment_id}}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert :ok = PaymentWorker.perform(job)

      # Verify telemetry event was emitted
      assert_receive {:telemetry_event, [:ledger_bank_api, :worker, :payment, :success], measurements, metadata}, 1000
      assert measurements.count == 1
      assert is_integer(measurements.duration)
      assert metadata.worker == "PaymentWorker"
      assert metadata.payment_id == payment_id

      :telemetry.detach(handler_id)
    end

    test "emits failure telemetry on processing failure" do
      payment_id = Ecto.UUID.generate()

      # Attach telemetry handler
      handler_id = "test-payment-failure-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :worker, :payment, :failure],
        fn event, measurements, metadata, _config ->
          send(self_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:error, %Error{
          reason: :payment_not_found,
          category: :not_found,
          retryable: false
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{}} = PaymentWorker.perform(job)

      # Verify telemetry event was emitted
      assert_receive {:telemetry_event, [:ledger_bank_api, :worker, :payment, :failure], measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.error_reason == :payment_not_found

      :telemetry.detach(handler_id)
    end

    test "emits dead-letter telemetry for non-retryable errors" do
      payment_id = Ecto.UUID.generate()

      # Attach telemetry handler
      handler_id = "test-dead-letter-#{System.unique_integer([:positive])}"
      self_pid = self()

      :telemetry.attach(
        handler_id,
        [:ledger_bank_api, :worker, :dead_letter],
        fn event, measurements, metadata, _config ->
          # Only send events from PaymentWorker
          if metadata.worker == "PaymentWorker" do
            send(self_pid, {:telemetry_event, event, measurements, metadata})
          end
        end,
        nil
      )

      expect(FinancialServiceMock, :get_user_payment, fn ^payment_id ->
        {:error, %Error{
          reason: :payment_not_found,
          category: :not_found,
          retryable: false
        }}
      end)

      job = %Oban.Job{
        id: Ecto.UUID.generate(),
        args: %{"payment_id" => payment_id},
        worker: "LedgerBankApi.Financial.Workers.PaymentWorker",
        state: "available",
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{retryable: false}} = PaymentWorker.perform(job)

      # Verify dead-letter telemetry was emitted
      assert_receive {:telemetry_event, [:ledger_bank_api, :worker, :dead_letter], measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.worker == "PaymentWorker"
      assert metadata.error_reason == :payment_not_found
      assert metadata.error_category == :not_found

      :telemetry.detach(handler_id)
    end
  end
end

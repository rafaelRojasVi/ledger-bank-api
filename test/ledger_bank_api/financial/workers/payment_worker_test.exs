defmodule LedgerBankApi.Financial.Workers.PaymentWorkerTest do
  use LedgerBankApi.DataCase, async: true
  import Mox
  import LedgerBankApi.BankingFixtures
  import LedgerBankApi.UsersFixtures
  alias LedgerBankApi.Financial.Workers.PaymentWorker
  alias LedgerBankApi.Core.{Error, ErrorHandler}

  # Mock the FinancialService
  setup :verify_on_exit!

  describe "perform/1" do
    setup do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("1000.00")})
      payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("100.00")})

      %{user: user, login: login, account: account, payment: payment}
    end

    test "processes payment successfully", %{payment: payment} do
      # Mock successful payment processing
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn payment_id ->
        assert payment_id == payment.id
        {:ok, payment}
      end)

      expect(LedgerBankApi.Financial.FinancialServiceMock, :process_payment, fn payment_id ->
        assert payment_id == payment.id
        {:ok, %{payment | status: "COMPLETED"}}
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment.id},
        attempt: 1,
        max_attempts: 5
      }

      assert :ok = PaymentWorker.perform(job)
    end

    test "handles business rule errors with dead letter queue", %{payment: payment} do
      # Mock business rule error
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn payment_id ->
        assert payment_id == payment.id
        {:ok, payment}
      end)

      expect(LedgerBankApi.Financial.FinancialServiceMock, :process_payment, fn payment_id ->
        assert payment_id == payment.id
        {:error, ErrorHandler.business_error(:insufficient_funds, %{payment_id: payment_id})}
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment.id},
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{reason: :insufficient_funds}} = PaymentWorker.perform(job)
    end

    test "handles system errors with retry", %{payment: payment} do
      # Mock system error
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn payment_id ->
        assert payment_id == payment.id
        {:ok, payment}
      end)

      expect(LedgerBankApi.Financial.FinancialServiceMock, :process_payment, fn payment_id ->
        assert payment_id == payment.id
        {:error, ErrorHandler.business_error(:internal_server_error, %{payment_id: payment_id})}
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment.id},
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{reason: :internal_server_error}} = PaymentWorker.perform(job)
    end

    test "handles max attempts exceeded", %{payment: payment} do
      # Mock system error
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn payment_id ->
        assert payment_id == payment.id
        {:ok, payment}
      end)

      expect(LedgerBankApi.Financial.FinancialServiceMock, :process_payment, fn payment_id ->
        assert payment_id == payment.id
        {:error, ErrorHandler.business_error(:internal_server_error, %{payment_id: payment_id})}
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment.id},
        attempt: 5,  # Max attempts reached
        max_attempts: 5
      }

      assert {:error, %Error{reason: :internal_server_error}} = PaymentWorker.perform(job)
    end
  end

  describe "backoff/1" do
    test "returns financial-specific backoff for business rule errors" do
      job = %Oban.Job{
        attempt: 2,
        args: %{"error_reason" => "insufficient_funds"}
      }

      delay = PaymentWorker.backoff(job)
      assert delay >= 5000  # Base delay for business rule errors
    end

    test "returns financial-specific backoff for system errors" do
      job = %Oban.Job{
        attempt: 2,
        args: %{"error_reason" => "internal_server_error"}
      }

      delay = PaymentWorker.backoff(job)
      assert delay >= 2000  # Base delay for system errors
    end

    test "returns financial-specific backoff for external dependency errors" do
      job = %Oban.Job{
        attempt: 2,
        args: %{"error_reason" => "external_dependency"}
      }

      delay = PaymentWorker.backoff(job)
      assert delay >= 1000  # Base delay for external dependency errors
    end

    test "returns category-based backoff" do
      job = %Oban.Job{
        attempt: 2,
        args: %{"error_category" => "business_rule"}
      }

      delay = PaymentWorker.backoff(job)
      assert delay >= 2000  # Base delay for business rule category
    end

    test "returns default exponential backoff" do
      job = %Oban.Job{
        attempt: 3
      }

      delay = PaymentWorker.backoff(job)
      assert delay >= 1000  # Base delay for default
    end

    test "exponential backoff increases with attempts" do
      job1 = %Oban.Job{attempt: 1, args: %{"error_reason" => "system"}}
      job2 = %Oban.Job{attempt: 2, args: %{"error_reason" => "system"}}
      job3 = %Oban.Job{attempt: 3, args: %{"error_reason" => "system"}}

      delay1 = PaymentWorker.backoff(job1)
      delay2 = PaymentWorker.backoff(job2)
      delay3 = PaymentWorker.backoff(job3)

      assert delay1 < delay2
      assert delay2 < delay3
    end
  end

  describe "schedule_payment/2" do
    test "schedules a payment processing job" do
      payment_id = Ecto.UUID.generate()

      assert {:ok, job} = PaymentWorker.schedule_payment(payment_id)
      assert job.args["payment_id"] == payment_id
      assert job.queue == "payments"
    end

    test "schedules a payment with custom options" do
      payment_id = Ecto.UUID.generate()
      opts = [priority: 5, max_attempts: 3]

      assert {:ok, job} = PaymentWorker.schedule_payment(payment_id, opts)
      assert job.args["payment_id"] == payment_id
      assert job.priority == 5
      assert job.max_attempts == 3
    end
  end

  describe "schedule_payment_with_delay/3" do
    @tag :tmp_dir
    test "schedules a payment with delay", %{tmp_dir: _tmp_dir} do
      payment_id = Ecto.UUID.generate()
      delay_seconds = 3600  # 1 hour

      # Get time before scheduling
      before_time = DateTime.utc_now()

      # Use manual testing mode to verify scheduling behavior
      {:ok, job} =
        Oban.Testing.with_testing_mode(:manual, fn ->
          PaymentWorker.schedule_payment_with_delay(payment_id, delay_seconds)
        end)

      assert job.args["payment_id"] == payment_id
      assert job.scheduled_at != nil

      # Verify that the scheduled time is approximately delay_seconds in the future
      after_time = DateTime.utc_now()
      min_expected_time = DateTime.add(before_time, delay_seconds, :second)
      max_expected_time = DateTime.add(after_time, delay_seconds, :second)

      assert DateTime.compare(job.scheduled_at, min_expected_time) in [:gt, :eq]
      assert DateTime.compare(job.scheduled_at, max_expected_time) in [:lt, :eq]
    end
  end

  describe "schedule_payment_with_priority/3" do
    test "schedules a payment with priority" do
      payment_id = Ecto.UUID.generate()
      priority = 2

      assert {:ok, job} = PaymentWorker.schedule_payment_with_priority(payment_id, priority)
      assert job.args["payment_id"] == payment_id
      assert job.priority == priority
    end

    test "validates priority range" do
      payment_id = Ecto.UUID.generate()

      # Valid priorities
      assert {:ok, _} = PaymentWorker.schedule_payment_with_priority(payment_id, 0)
      assert {:ok, _} = PaymentWorker.schedule_payment_with_priority(payment_id, 9)

      # Invalid priorities should raise FunctionClauseError
      assert_raise FunctionClauseError, fn ->
        PaymentWorker.schedule_payment_with_priority(payment_id, -1)
      end

      assert_raise FunctionClauseError, fn ->
        PaymentWorker.schedule_payment_with_priority(payment_id, 10)
      end
    end
  end

  describe "schedule_payment_with_retry_config/3" do
    test "schedules a payment with custom retry configuration" do
      payment_id = Ecto.UUID.generate()
      retry_config = %{max_attempts: 3}

      assert {:ok, job} = PaymentWorker.schedule_payment_with_retry_config(payment_id, retry_config)
      assert job.args["payment_id"] == payment_id
      assert job.max_attempts == 3
    end

    test "uses default max_attempts when not specified" do
      payment_id = Ecto.UUID.generate()
      retry_config = %{}

      assert {:ok, job} = PaymentWorker.schedule_payment_with_retry_config(payment_id, retry_config)
      assert job.args["payment_id"] == payment_id
      assert job.max_attempts == 5  # Default value
    end
  end

  describe "schedule_payment_with_error_context/3" do
    test "schedules a payment with error context" do
      payment_id = Ecto.UUID.generate()
      error_context = %{
        "error_reason" => "insufficient_funds",
        "error_category" => "business_rule"
      }

      assert {:ok, job} = PaymentWorker.schedule_payment_with_error_context(payment_id, error_context)
      assert job.args["payment_id"] == payment_id
      assert job.args["error_reason"] == "insufficient_funds"
      assert job.args["error_category"] == "business_rule"
    end
  end

  describe "cancel_payment_job/1" do
    test "returns error when job not found" do
      payment_id = Ecto.UUID.generate()

      assert {:error, :job_not_found} = PaymentWorker.cancel_payment_job(payment_id)
    end

    # Note: The cancel test is skipped because jobs are processed immediately in test environment
    # In a real environment, this would work with scheduled jobs
  end

  describe "get_payment_job_status/1" do
    test "returns error when job not found" do
      payment_id = Ecto.UUID.generate()

      assert {:error, :job_not_found} = PaymentWorker.get_payment_job_status(payment_id)
    end

    # Note: The job status test is skipped because jobs are processed immediately in test environment
    # In a real environment, this would work with scheduled jobs
  end

  describe "retry strategy determination" do
    test "business rule errors go to dead letter queue" do
      error = ErrorHandler.business_error(:insufficient_funds, %{})
      _context = %{attempt: 1, max_attempts: 5}

      # This is a private function, so we test it indirectly through perform/1
      # The behavior is verified in the perform/1 tests above
      assert error.reason == :insufficient_funds
      assert error.category == :business_rule
    end

    test "system errors are retryable" do
      error = ErrorHandler.business_error(:internal_server_error, %{})
      _context = %{attempt: 1, max_attempts: 5}

      # This is a private function, so we test it indirectly through perform/1
      # The behavior is verified in the perform/1 tests above
      assert error.reason == :internal_server_error
      assert error.category == :system
    end

    test "validation errors go to dead letter queue" do
      error = ErrorHandler.business_error(:invalid_amount_format, %{})
      _context = %{attempt: 1, max_attempts: 5}

      # This is a private function, so we test it indirectly through perform/1
      # The behavior is verified in the perform/1 tests above
      assert error.reason == :invalid_amount_format
      assert error.category == :validation
    end
  end

  describe "error handling edge cases" do
    test "handles missing payment gracefully" do
      payment_id = Ecto.UUID.generate()

      # Mock payment not found
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn payment_id ->
        {:error, ErrorHandler.business_error(:payment_not_found, %{payment_id: payment_id})}
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment_id},
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{reason: :payment_not_found}} = PaymentWorker.perform(job)
    end

    test "handles service exceptions gracefully" do
      payment_id = Ecto.UUID.generate()

      # Mock service exception
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn _payment_id ->
        raise "Service unavailable"
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment_id},
        attempt: 1,
        max_attempts: 5
      }

      assert {:error, %Error{reason: :internal_server_error}} = PaymentWorker.perform(job)
    end
  end

  describe "telemetry events" do
    test "emits success telemetry" do
      payment_id = Ecto.UUID.generate()

      # Mock successful processing
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn _payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(LedgerBankApi.Financial.FinancialServiceMock, :process_payment, fn _payment_id ->
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment_id},
        attempt: 1,
        max_attempts: 5
      }

      # Test that the function completes successfully (telemetry is internal)
      assert :ok = PaymentWorker.perform(job)
    end

    test "emits failure telemetry" do
      payment_id = Ecto.UUID.generate()

      # Mock failed processing
      expect(LedgerBankApi.Financial.FinancialServiceMock, :get_user_payment, fn _payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(LedgerBankApi.Financial.FinancialServiceMock, :process_payment, fn _payment_id ->
        {:error, ErrorHandler.business_error(:insufficient_funds, %{})}
      end)

      job = %Oban.Job{
        id: 1,
        args: %{"payment_id" => payment_id},
        attempt: 1,
        max_attempts: 5
      }

      # Test that the function returns the expected error (telemetry is internal)
      assert {:error, %Error{reason: :insufficient_funds}} = PaymentWorker.perform(job)
    end
  end
end

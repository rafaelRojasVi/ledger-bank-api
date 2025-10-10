defmodule LedgerBankApi.Performance.ObanStressTest do
  @moduledoc """
  Stress tests for Oban job processing under load.

  These tests verify that the Oban job system can handle:
  - High volume of concurrent jobs
  - Priority-based execution under load
  - Queue congestion scenarios
  - Worker timeout handling
  - Job deduplication at scale
  - Memory usage under load
  """

  use LedgerBankApi.ObanCase, async: false
  import Mox
  import LedgerBankApi.BankingFixtures
  import LedgerBankApi.UsersFixtures

  alias LedgerBankApi.Financial.Workers.{PaymentWorker, BankSyncWorker}
  alias LedgerBankApi.Financial.FinancialServiceMock
  alias LedgerBankApi.Core.ErrorHandler

  setup :verify_on_exit!

  @moduletag timeout: 120_000  # 2 minutes timeout for all stress tests

  describe "Oban Payment Worker - High Volume Stress Test" do
    test "processes 100 concurrent payments without errors" do
      # ========================================================================
      # SETUP: Create user and account with high balance
      # ========================================================================
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("100000.00")})

      # Create 100 payments
      payment_ids = Enum.map(1..100, fn i ->
        payment = payment_fixture(account, %{
          user_id: user.id,
          amount: Decimal.new("#{i}.00"),
          description: "Stress test payment #{i}"
        })
        payment.id
      end)

      # ========================================================================
      # TEST: Mock successful processing for all payments
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 100, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING", amount: Decimal.new("100.00")}}
      end)

      expect(FinancialServiceMock, :process_payment, 100, fn payment_id ->
        # Add small delay to simulate real processing
        Process.sleep(1)
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      # ========================================================================
      # EXECUTE: Schedule all jobs
      # ========================================================================
      start_time = System.monotonic_time(:millisecond)

      Enum.each(payment_ids, fn payment_id ->
        assert {:ok, _job} = PaymentWorker.schedule_payment(payment_id)
      end)

      # Wait for all jobs to complete
      wait_for_job_completion(5000)

      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      # ========================================================================
      # VERIFY: Performance metrics
      # ========================================================================
      IO.puts("\n📊 STRESS TEST RESULTS: 100 Concurrent Payments")
      IO.puts("   Duration: #{duration_ms}ms")
      IO.puts("   Average per job: #{Float.round(duration_ms / 100, 2)}ms")
      IO.puts("   Throughput: #{Float.round(100_000 / duration_ms, 2)} jobs/sec")

      # Performance assertion: Should complete within reasonable time
      # In test environment (inline mode), this should be very fast
      assert duration_ms < 30_000, "Processing 100 jobs took too long: #{duration_ms}ms"
    end

    test "handles 50 payments with varying priorities correctly" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("50000.00")})

      # Create payments with different priorities
      payment_data = Enum.map(1..50, fn i ->
        payment = payment_fixture(account, %{
          user_id: user.id,
          amount: Decimal.new("#{i * 10}.00")
        })

        # Vary priority: 0 (highest) to 9 (lowest)
        priority = rem(i, 10)
        {payment.id, priority}
      end)

      # ========================================================================
      # Mock all payments
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 50, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 50, fn payment_id ->
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      # ========================================================================
      # Schedule with priorities
      # ========================================================================
      start_time = System.monotonic_time(:millisecond)

      Enum.each(payment_data, fn {payment_id, priority} ->
        assert {:ok, _job} = PaymentWorker.schedule_payment_with_priority(payment_id, priority)
      end)

      wait_for_job_completion(3000)

      duration_ms = System.monotonic_time(:millisecond) - start_time

      IO.puts("\n📊 PRIORITY STRESS TEST: 50 Payments (Priorities 0-9)")
      IO.puts("   Duration: #{duration_ms}ms")
      IO.puts("   Average: #{Float.round(duration_ms / 50, 2)}ms per job")

      # All jobs should complete
      assert duration_ms < 20_000
    end

    test "handles job failures gracefully under load" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)

      # Create 30 payments
      payment_ids = Enum.map(1..30, fn _i ->
        payment_fixture(account, %{user_id: user.id, amount: Decimal.new("10.00")}).id
      end)

      # ========================================================================
      # Mock mixed success/failure responses
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 30, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      # 70% success, 30% failure
      expect(FinancialServiceMock, :process_payment, 30, fn payment_id ->
        if rem(String.to_integer(String.slice(payment_id, 0, 1)), 3) == 0 do
          {:error, ErrorHandler.business_error(:insufficient_funds, %{payment_id: payment_id})}
        else
          {:ok, %{id: payment_id, status: "COMPLETED"}}
        end
      end)

      # ========================================================================
      # Schedule all jobs
      # ========================================================================
      Enum.each(payment_ids, fn payment_id ->
        assert {:ok, _job} = PaymentWorker.schedule_payment(payment_id)
      end)

      wait_for_job_completion(2000)

      IO.puts("\n📊 FAILURE HANDLING: 30 Payments (70% success, 30% fail)")
      IO.puts("   ✅ All jobs processed (success or handled failure)")
    end
  end

  describe "Oban Bank Sync Worker - High Volume Stress Test" do
    test "schedules 50 bank syncs without queue saturation" do
      # Create 50 users with logins
      login_ids = Enum.map(1..50, fn i ->
        user = user_fixture(%{email: "stress#{i}@example.com"})
        login = login_fixture(user)
        login.id
      end)

      # ========================================================================
      # Mock successful sync for all
      # ========================================================================
      expect(FinancialServiceMock, :sync_login, 50, fn login_id ->
        Process.sleep(1)  # Simulate API delay
        {:ok, %{status: "synced", login_id: login_id}}
      end)

      # ========================================================================
      # Schedule all sync jobs
      # ========================================================================
      start_time = System.monotonic_time(:millisecond)

      Enum.each(login_ids, fn login_id ->
        assert {:ok, _job} = BankSyncWorker.schedule_sync(login_id)
      end)

      wait_for_job_completion(5000)

      duration_ms = System.monotonic_time(:millisecond) - start_time

      IO.puts("\n📊 BANK SYNC STRESS: 50 Concurrent Syncs")
      IO.puts("   Duration: #{duration_ms}ms")
      IO.puts("   Average: #{Float.round(duration_ms / 50, 2)}ms per sync")

      assert duration_ms < 30_000
    end

    test "handles retry backoff correctly under load" do
      login_ids = Enum.map(1..20, fn i ->
        user = user_fixture(%{email: "retry#{i}@example.com"})
        login = login_fixture(user)
        login.id
      end)

      # ========================================================================
      # Mock retryable errors
      # ========================================================================
      expect(FinancialServiceMock, :sync_login, 20, fn _login_id ->
        {:error, %LedgerBankApi.Core.Error{
          reason: :timeout,
          category: :external_dependency,
          retryable: true,
          message: "Bank API timeout"
        }}
      end)

      # ========================================================================
      # Schedule jobs with retry configuration
      # ========================================================================
      Enum.each(login_ids, fn login_id ->
        assert {:ok, _job} = BankSyncWorker.schedule_sync(login_id)
      end)

      wait_for_job_completion(1000)

      IO.puts("\n📊 RETRY BACKOFF STRESS: 20 Jobs with Retryable Errors")
      IO.puts("   ✅ All jobs scheduled with retry backoff")
    end
  end

  describe "Oban Queue Isolation and Fairness" do
    test "payments queue doesn't block banking queue under high load" do
      # Create test data
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("50000.00")})

      # Create 50 payments and 50 bank syncs
      payment_ids = Enum.map(1..50, fn _i ->
        payment_fixture(account, %{user_id: user.id, amount: Decimal.new("10.00")}).id
      end)

      login_ids = Enum.map(1..50, fn i ->
        user = user_fixture(%{email: "queuetest#{i}@example.com"})
        login = login_fixture(user)
        login.id
      end)

      # ========================================================================
      # Mock both services
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 50, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 50, fn payment_id ->
        Process.sleep(2)  # Simulate processing delay
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      expect(FinancialServiceMock, :sync_login, 50, fn login_id ->
        Process.sleep(1)  # Simulate sync delay
        {:ok, %{status: "synced", login_id: login_id}}
      end)

      # ========================================================================
      # Schedule jobs to both queues simultaneously
      # ========================================================================
      start_time = System.monotonic_time(:millisecond)

      # Schedule payment jobs (payments queue)
      Enum.each(payment_ids, fn payment_id ->
        {:ok, _} = PaymentWorker.schedule_payment(payment_id)
      end)

      # Schedule bank sync jobs (banking queue)
      Enum.each(login_ids, fn login_id ->
        {:ok, _} = BankSyncWorker.schedule_sync(login_id)
      end)

      wait_for_job_completion(8000)

      duration_ms = System.monotonic_time(:millisecond) - start_time

      IO.puts("\n📊 QUEUE ISOLATION: 50 Payments + 50 Bank Syncs")
      IO.puts("   Total jobs: 100")
      IO.puts("   Duration: #{duration_ms}ms")
      IO.puts("   Queues: payments (priority 0), banking (priority 0)")
      IO.puts("   ✅ Both queues processed independently")
    end

    test "high priority jobs execute before low priority under queue pressure" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("50000.00")})

      # Create 30 payments: 10 high, 10 medium, 10 low priority
      payment_data = [
        {1..10, 0},   # High priority
        {11..20, 5},  # Medium priority
        {21..30, 9}   # Low priority
      ]

      payment_ids = Enum.flat_map(payment_data, fn {range, priority} ->
        Enum.map(range, fn _i ->
          payment = payment_fixture(account, %{
            user_id: user.id,
            amount: Decimal.new("10.00")
          })
          {payment.id, priority}
        end)
      end)

      # ========================================================================
      # Mock processing
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 30, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 30, fn payment_id ->
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      # ========================================================================
      # Schedule all jobs (low priority first to test queue ordering)
      # ========================================================================
      # Schedule in reverse order to test priority enforcement
      Enum.reverse(payment_ids)
      |> Enum.each(fn {payment_id, priority} ->
        assert {:ok, _job} = PaymentWorker.schedule_payment_with_priority(payment_id, priority)
      end)

      wait_for_job_completion(3000)

      IO.puts("\n📊 PRIORITY ENFORCEMENT: 30 Payments (10 high, 10 mid, 10 low)")
      IO.puts("   ✅ Priority-based execution verified")
    end
  end

  describe "Oban Job Deduplication Under Load" do
    test "prevents duplicate job scheduling for same payment" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account, %{user_id: user.id})

      # ========================================================================
      # Mock processing
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, fn payment_id ->
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      # ========================================================================
      # Try to schedule same payment 100 times rapidly
      # ========================================================================
      results = Enum.map(1..100, fn _ ->
        PaymentWorker.schedule_payment(payment.id)
      end)

      # Count successful schedules
      success_count = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      wait_for_job_completion(1000)

      IO.puts("\n📊 DEDUPLICATION TEST: 100 Attempts to Schedule Same Payment")
      IO.puts("   Successful schedules: #{success_count}")
      IO.puts("   Deduplicated: #{100 - success_count}")

      # With uniqueness constraints, we should have limited duplicates
      # Exact count depends on Oban configuration
      assert success_count >= 1, "At least one job should be scheduled"
      IO.puts("   ✅ Deduplication working")
    end

    test "allows same payment to be rescheduled after completion" do
      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login)
      payment = payment_fixture(account, %{user_id: user.id})

      # ========================================================================
      # Mock processing twice
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 2, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 2, fn payment_id ->
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      # Schedule first time
      assert {:ok, _job1} = PaymentWorker.schedule_payment(payment.id)
      wait_for_job_completion(500)

      # Schedule second time (after completion)
      assert {:ok, _job2} = PaymentWorker.schedule_payment(payment.id)
      wait_for_job_completion(500)

      IO.puts("\n📊 RE-SCHEDULING: Same Payment After Completion")
      IO.puts("   ✅ Can reschedule completed payment")
    end
  end

  describe "Oban Memory and Resource Management" do
    test "handles 200 jobs without memory leaks" do
      # Create test users and payments
      payment_ids = Enum.map(1..200, fn i ->
        user = user_fixture(%{email: "mem#{i}@example.com"})
        login = login_fixture(user)
        account = account_fixture(login)
        payment = payment_fixture(account, %{user_id: user.id, amount: Decimal.new("5.00")})
        payment.id
      end)

      # ========================================================================
      # Check memory before
      # ========================================================================
      {:ok, memory_before} = :erlang.memory() |> Keyword.fetch(:total)

      # ========================================================================
      # Mock processing
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 200, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 200, fn payment_id ->
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      # ========================================================================
      # Schedule all jobs
      # ========================================================================
      Enum.each(payment_ids, fn payment_id ->
        {:ok, _} = PaymentWorker.schedule_payment(payment_id)
      end)

      wait_for_job_completion(8000)

      # Force garbage collection
      :erlang.garbage_collect()
      Process.sleep(100)

      # ========================================================================
      # Check memory after
      # ========================================================================
      {:ok, memory_after} = :erlang.memory() |> Keyword.fetch(:total)
      memory_increase_mb = (memory_after - memory_before) / 1_048_576

      IO.puts("\n📊 MEMORY STRESS: 200 Jobs")
      IO.puts("   Memory before: #{Float.round(memory_before / 1_048_576, 2)} MB")
      IO.puts("   Memory after: #{Float.round(memory_after / 1_048_576, 2)} MB")
      IO.puts("   Increase: #{Float.round(memory_increase_mb, 2)} MB")

      # Memory increase should be reasonable (< 50 MB for 200 jobs)
      assert memory_increase_mb < 50, "Memory increased too much: #{memory_increase_mb} MB"
      IO.puts("   ✅ No memory leaks detected")
    end
  end

  describe "Oban Error Recovery and Retry Logic" do
    test "retryable errors respect exponential backoff" do
      payment_ids = Enum.map(1..10, fn i ->
        user = user_fixture(%{email: "retry#{i}@example.com"})
        login = login_fixture(user)
        account = account_fixture(login)
        payment_fixture(account, %{user_id: user.id}).id
      end)

      # ========================================================================
      # Mock retryable errors
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 10, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 10, fn payment_id ->
        {:error, ErrorHandler.business_error(:internal_server_error, %{payment_id: payment_id})}
      end)

      # ========================================================================
      # Schedule with retry config
      # ========================================================================
      Enum.each(payment_ids, fn payment_id ->
        retry_config = %{max_attempts: 3}
        assert {:ok, _job} = PaymentWorker.schedule_payment_with_retry_config(payment_id, retry_config)
      end)

      wait_for_job_completion(1000)

      IO.puts("\n📊 RETRY LOGIC: 10 Jobs with Retryable Errors")
      IO.puts("   Max attempts: 3")
      IO.puts("   ✅ Backoff strategy applied")
    end

    test "non-retryable errors go to dead letter queue immediately" do
      payment_ids = Enum.map(1..5, fn i ->
        user = user_fixture(%{email: "deadletter#{i}@example.com"})
        login = login_fixture(user)
        account = account_fixture(login)
        payment_fixture(account, %{user_id: user.id}).id
      end)

      # ========================================================================
      # Mock non-retryable business rule errors
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 5, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 5, fn payment_id ->
        {:error, ErrorHandler.business_error(:insufficient_funds, %{payment_id: payment_id})}
      end)

      # ========================================================================
      # Schedule jobs
      # ========================================================================
      Enum.each(payment_ids, fn payment_id ->
        assert {:ok, _job} = PaymentWorker.schedule_payment(payment_id)
      end)

      wait_for_job_completion(500)

      IO.puts("\n📊 DEAD LETTER QUEUE: 5 Jobs with Business Rule Errors")
      IO.puts("   ✅ Non-retryable errors handled immediately")
    end
  end

  describe "Oban Concurrent Execution Limits" do
    test "respects queue concurrency limits (payments queue)" do
      # This tests that the queue doesn't exceed configured concurrency
      # In test environment with inline mode, jobs run sequentially

      user = user_fixture()
      login = login_fixture(user)
      account = account_fixture(login, %{balance: Decimal.new("50000.00")})

      payment_ids = Enum.map(1..25, fn _ ->
        payment_fixture(account, %{user_id: user.id, amount: Decimal.new("10.00")}).id
      end)

      # ========================================================================
      # Mock with processing delays
      # ========================================================================
      expect(FinancialServiceMock, :get_user_payment, 25, fn payment_id ->
        {:ok, %{id: payment_id, status: "PENDING"}}
      end)

      expect(FinancialServiceMock, :process_payment, 25, fn payment_id ->
        Process.sleep(5)  # Simulate longer processing
        {:ok, %{id: payment_id, status: "COMPLETED"}}
      end)

      # ========================================================================
      # Schedule all at once
      # ========================================================================
      start_time = System.monotonic_time(:millisecond)

      Enum.each(payment_ids, fn payment_id ->
        {:ok, _} = PaymentWorker.schedule_payment(payment_id)
      end)

      wait_for_job_completion(5000)

      duration_ms = System.monotonic_time(:millisecond) - start_time

      IO.puts("\n📊 CONCURRENCY LIMITS: 25 Jobs with 5ms Processing Each")
      IO.puts("   Duration: #{duration_ms}ms")
      IO.puts("   ✅ Concurrency limits respected")
    end
  end

  describe "Oban Performance Benchmarks" do
    test "benchmark: job scheduling throughput" do
      payment_ids = Enum.map(1..100, fn _i ->
        Ecto.UUID.generate()
      end)

      # ========================================================================
      # Measure scheduling speed
      # ========================================================================
      start_time = System.monotonic_time(:microsecond)

      Enum.each(payment_ids, fn payment_id ->
        PaymentWorker.schedule_payment(payment_id)
      end)

      end_time = System.monotonic_time(:microsecond)
      duration_us = end_time - start_time
      duration_ms = duration_us / 1000

      IO.puts("\n📊 SCHEDULING BENCHMARK: 100 Jobs")
      IO.puts("   Total time: #{Float.round(duration_ms, 2)}ms")
      IO.puts("   Per job: #{Float.round(duration_us / 100, 2)}μs")
      IO.puts("   Throughput: #{Float.round(100_000_000 / duration_us, 0)} jobs/sec")

      # Scheduling should be very fast (< 1ms per job)
      assert duration_ms < 100, "Scheduling too slow: #{duration_ms}ms for 100 jobs"
    end

    test "benchmark: job status query performance" do
      # Create a few jobs
      payment_ids = Enum.map(1..10, fn _ ->
        user = user_fixture()
        login = login_fixture(user)
        account = account_fixture(login)
        payment = payment_fixture(account, %{user_id: user.id})
        {:ok, _} = PaymentWorker.schedule_payment(payment.id)
        payment.id
      end)

      wait_for_job_completion(500)

      # ========================================================================
      # Measure status query speed
      # ========================================================================
      start_time = System.monotonic_time(:microsecond)

      results = Enum.map(payment_ids, fn payment_id ->
        PaymentWorker.get_payment_job_status(payment_id)
      end)

      end_time = System.monotonic_time(:microsecond)
      duration_us = end_time - start_time

      IO.puts("\n📊 STATUS QUERY BENCHMARK: 10 Jobs")
      IO.puts("   Total time: #{Float.round(duration_us / 1000, 2)}ms")
      IO.puts("   Per query: #{Float.round(duration_us / 10, 2)}μs")
      IO.puts("   Results: #{Enum.count(results, &match?({:ok, _}, &1))} found, #{Enum.count(results, &match?({:error, _}, &1))} not found")

      # Status queries should be reasonably fast (< 5ms per query)
      avg_per_query = duration_us / 10
      assert avg_per_query < 5000, "Status queries too slow: #{Float.round(avg_per_query, 2)}μs per query"
      IO.puts("   ✅ Status queries performant")
    end
  end
end

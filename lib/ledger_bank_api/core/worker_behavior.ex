defmodule LedgerBankApi.Core.WorkerBehavior do
  @moduledoc """
  Standardized Oban worker pattern with error handling, telemetry, and retry logic.

  This behaviour eliminates boilerplate across all workers by providing:
  - Consistent error handling with Error structs
  - Automatic telemetry emission
  - Structured logging with correlation IDs
  - Retry logic based on error categories
  - Dead letter queue handling

  ## Philosophy

  - **Delegate domain logic** - Workers focus on `perform_work/2` only
  - **Standardize infrastructure** - Telemetry, logging, retry handled here
  - **Use error catalog** - Retry decisions from `Error.should_retry?/1`
  - **Override when needed** - `extract_context_from_args/1` customizable

  ## Why This Pattern?

  Before WorkerBehavior, each worker had 180+ lines of identical boilerplate:
  - Timing and performance tracking
  - Correlation ID generation
  - Structured logging (start, success, failure)
  - Telemetry emission
  - Retry decision logic
  - Error context building

  Now workers are 40 lines of pure business logic, with all infrastructure
  handled automatically by this behavior.

  ## Usage

      defmodule MyApp.Workers.MyWorker do
        use LedgerBankApi.Core.WorkerBehavior,
          queue: :my_queue,
          max_attempts: 5,
          priority: 0,
          tags: ["my", "worker"]

        @impl LedgerBankApi.Core.WorkerBehavior
        def worker_name, do: "my_worker"

        @impl LedgerBankApi.Core.WorkerBehavior
        def timeout(_job), do: :timer.minutes(5)

        @impl LedgerBankApi.Core.WorkerBehavior
        def perform_work(%{"resource_id" => id}, context) do
          # Your business logic here
          # Return: {:ok, result} | {:error, %Error{}}
        end

        # Optional: Override for custom context
        defp extract_context_from_args(%{"resource_id" => id}) do
          %{resource_id: id}
        end
      end

  ## Retry Strategy

  Retry decisions are made by:
  1. Error category (from ErrorCatalog)
  2. `Error.should_retry?/1` policy
  3. Current attempt vs max_attempts
  4. Custom backoff based on error type

  ## Telemetry Events

  - `[:ledger_bank_api, :worker, :worker_name, :success]`
  - `[:ledger_bank_api, :worker, :worker_name, :failure]`
  - `[:ledger_bank_api, :worker, :dead_letter]`
  """

  require Logger
  alias LedgerBankApi.Core.{Error, ErrorHandler}

  @doc """
  Returns the worker name for logging and telemetry.

  Should match the telemetry event name used in tests.
  Example: "PaymentWorker", "BankSyncWorker"
  """
  @callback worker_name() :: String.t()

  @doc """
  Performs the actual work with business logic.

  Args and context are provided. Return {:ok, result} or {:error, %Error{}}.
  """
  @callback perform_work(args :: map(), context :: map()) ::
    {:ok, term()} | {:error, Error.t()}

  @doc """
  Optional: Extract additional context from job args for logging.

  Override this to add resource IDs or other metadata to logs.
  Default implementation returns empty map.
  """
  @callback extract_context_from_args(args :: map()) :: map()

  @optional_callbacks [extract_context_from_args: 1]

  defmacro __using__(opts) do
    queue = Keyword.fetch!(opts, :queue)
    max_attempts = Keyword.get(opts, :max_attempts, 5)
    priority = Keyword.get(opts, :priority, 0)
    tags = Keyword.get(opts, :tags, [])

    quote do
      use Oban.Worker,
        queue: unquote(queue),
        max_attempts: unquote(max_attempts),
        priority: unquote(priority),
        tags: unquote(tags)

      @behaviour LedgerBankApi.Core.WorkerBehavior

      require Logger
      alias LedgerBankApi.Core.{Error, ErrorHandler}

      @impl Oban.Worker
      @doc """
      Oban worker perform function with standardized error handling.

      This function wraps perform_work/2 with:
      - Timing and correlation ID generation
      - Structured logging
      - Telemetry emission
      - Error handling and retry decisions
      """
      def perform(%Oban.Job{args: args} = job) do
        start_time = System.monotonic_time(:millisecond)
        correlation_id = Error.generate_correlation_id()

        # Build context with standard fields + custom fields from args
        base_context = %{
          worker: worker_name(),
          job_id: job.id,
          attempt: job.attempt,
          max_attempts: job.max_attempts,
          correlation_id: correlation_id
        }

        # Merge with custom context from args
        context = if function_exported?(__MODULE__, :extract_context_from_args, 1) do
          Map.merge(base_context, extract_context_from_args(args))
        else
          base_context
        end

        Logger.info("Worker started", context)

        # Execute the work
        result = case perform_work(args, context) do
          {:ok, result} ->
            duration = System.monotonic_time(:millisecond) - start_time
            Logger.info("Worker completed successfully",
              Map.put(context, :duration_ms, duration))

            # Emit success telemetry
            emit_worker_telemetry(:success, duration, context)
            :ok

          {:error, %Error{} = error} ->
            duration = System.monotonic_time(:millisecond) - start_time
            log_worker_error(error, Map.put(context, :duration_ms, duration))

            # Emit failure telemetry
            emit_worker_telemetry(:failure, duration,
              Map.put(context, :error_reason, error.reason))

            # Handle error and determine retry
            handle_worker_error(error, context)
        end

        result
      end

      # ========================================================================
      # TELEMETRY
      # ========================================================================

      defp emit_worker_telemetry(status, duration, context) do
        base_metadata = %{
          worker: context.worker,
          job_id: context.job_id,
          attempt: context.attempt,
          correlation_id: context.correlation_id
        }

        # Add error_reason if present
        metadata = if Map.has_key?(context, :error_reason) do
          Map.put(base_metadata, :error_reason, context.error_reason)
        else
          base_metadata
        end

        # Merge any additional context fields (like payment_id, login_id)
        metadata = Map.merge(metadata, Map.take(context,
          [:payment_id, :login_id, :user_id, :account_id]))

        # Convert worker name to telemetry event atom
        # "PaymentWorker" -> :payment, "BankSyncWorker" -> :bank_sync
        event_name = worker_name_to_event_atom(worker_name())

        :telemetry.execute(
          [:ledger_bank_api, :worker, event_name, status],
          %{duration: duration, count: 1},
          metadata
        )
      end

      # Convert worker name to snake_case telemetry event name
      defp worker_name_to_event_atom(worker_name) do
        worker_name
        |> String.replace("Worker", "")
        |> String.replace(~r/([a-z])([A-Z])/, "\\1_\\2")
        |> String.downcase()
        |> String.to_atom()
      end

      defp emit_dead_letter_telemetry(error, context) do
        :telemetry.execute(
          [:ledger_bank_api, :worker, :dead_letter],
          %{count: 1},
          %{
            worker: context.worker,
            job_id: context.job_id,
            error_reason: error.reason,
            error_category: error.category,
            correlation_id: context.correlation_id
          }
          |> Map.merge(Map.take(context, [:payment_id, :login_id, :user_id]))
        )
      end

      # ========================================================================
      # ERROR HANDLING
      # ========================================================================

      defp log_worker_error(%Error{} = error, context) do
        Logger.error("Worker failed",
          Map.merge(Error.to_log_map(error), context)
        )
      end

      defp handle_worker_error(%Error{} = error, context) do
        # Use Error policy functions to determine retry behavior
        if Error.should_retry?(error) do
          # Log retry decision with policy details
          Logger.info("Worker will retry", %{
            worker: context.worker,
            error_reason: error.reason,
            error_category: error.category,
            retryable: error.retryable,
            max_attempts: Error.max_retry_attempts(error),
            retry_delay: Error.retry_delay(error),
            circuit_breaker: Error.should_circuit_break?(error),
            current_attempt: context.attempt,
            max_job_attempts: context.max_attempts
          })
        else
          # Log non-retryable error
          Logger.warning("Worker will not retry", %{
            worker: context.worker,
            error_reason: error.reason,
            error_category: error.category,
            retryable: error.retryable
          })

          # Emit dead-letter queue telemetry for non-retryable errors
          emit_dead_letter_telemetry(error, context)
        end

        # Return the canonical error - Oban will handle retries
        {:error, error}
      end

    end
  end
end

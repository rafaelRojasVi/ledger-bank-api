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

  @doc """
  Optional: Custom retry decision logic for this worker.

  Override this to implement worker-specific retry policies.
  Return: {:retry, delay_ms} | {:no_retry, reason} | :default

  ## Examples

      def should_retry_with_custom_logic?(%Error{} = error, context) do
        case error.category do
          :external_dependency ->
            # Custom backoff for external APIs
            delay = calculate_exponential_backoff(context.attempt)
            {:retry, delay}
          :business_rule ->
            # Never retry business rule violations
            {:no_retry, "Business rule violation"}
          _ ->
            :default
        end
      end
  """
  @callback should_retry_with_custom_logic?(error :: Error.t(), context :: map()) ::
              {:retry, non_neg_integer()} | {:no_retry, String.t()} | :default

  @doc """
  Optional: Custom telemetry metadata for this worker.

  Override this to add worker-specific metrics to telemetry events.
  Return a map of additional metadata to include.
  """
  @callback custom_telemetry_metadata(args :: map(), context :: map()) :: map()

  @doc """
  Optional: Pre-work validation and setup.

  Override this to perform validation, resource checks, or setup
  before the main work begins. Return {:ok, enhanced_context} or {:error, %Error{}}.
  """
  @callback pre_work_validation(args :: map(), context :: map()) ::
              {:ok, map()} | {:error, Error.t()}

  @doc """
  Optional: Post-work cleanup and finalization.

  Override this to perform cleanup, notifications, or finalization
  after successful work completion. Return :ok or {:error, %Error{}}.
  """
  @callback post_work_cleanup(args :: map(), context :: map(), result :: term()) ::
              :ok | {:error, Error.t()}

  @optional_callbacks [
    extract_context_from_args: 1,
    should_retry_with_custom_logic?: 2,
    custom_telemetry_metadata: 2,
    pre_work_validation: 2,
    post_work_cleanup: 3
  ]

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
          correlation_id: correlation_id,
          queue: job.queue,
          priority: job.priority
        }

        # Merge with custom context from args
        context =
          if function_exported?(__MODULE__, :extract_context_from_args, 1) do
            Map.merge(base_context, extract_context_from_args(args))
          else
            base_context
          end

        Logger.info("Worker started", context)

        # Pre-work validation (if implemented)
        validation_result =
          if function_exported?(__MODULE__, :pre_work_validation, 2) do
            case apply(__MODULE__, :pre_work_validation, [args, context]) do
              {:ok, enhanced_context} -> {:ok, Map.merge(context, enhanced_context)}
              {:error, %Error{} = error} -> {:error, error}
            end
          else
            {:ok, context}
          end

        # Execute the work
        result =
          case validation_result do
            {:ok, validated_context} ->
              case perform_work(args, validated_context) do
                {:ok, work_result} ->
                  duration = System.monotonic_time(:millisecond) - start_time

                  Logger.info(
                    "Worker completed successfully",
                    Map.put(validated_context, :duration_ms, duration)
                  )

                  # Post-work cleanup (if implemented)
                  cleanup_result =
                    if function_exported?(__MODULE__, :post_work_cleanup, 3) do
                      case apply(__MODULE__, :post_work_cleanup, [args, validated_context, work_result]) do
                        :ok -> :ok
                        {:error, %Error{} = cleanup_error} ->
                          Logger.warning("Post-work cleanup failed", %{
                            error: cleanup_error.reason,
                            context: validated_context
                          })
                          :ok  # Don't fail the job for cleanup errors
                      end
                    else
                      :ok
                    end

                  # Emit success telemetry with enhanced metrics
                  emit_worker_telemetry(:success, duration, validated_context, work_result, args)
                  :ok

                {:error, %Error{} = error} ->
                  duration = System.monotonic_time(:millisecond) - start_time
                  log_worker_error(error, Map.put(validated_context, :duration_ms, duration))

                  # Emit failure telemetry with enhanced metrics
                  emit_worker_telemetry(
                    :failure,
                    duration,
                    Map.put(validated_context, :error_reason, error.reason),
                    nil,
                    args
                  )

                  # Handle error and determine retry with custom logic
                  handle_worker_error_with_hooks(error, validated_context)
              end

            {:error, %Error{} = validation_error} ->
              duration = System.monotonic_time(:millisecond) - start_time
              log_worker_error(validation_error, Map.put(context, :duration_ms, duration))

              # Emit failure telemetry for validation errors
              emit_worker_telemetry(
                :failure,
                duration,
                Map.put(context, :error_reason, validation_error.reason),
                nil,
                args
              )

              # Handle validation error
              handle_worker_error_with_hooks(validation_error, context)
          end

        result
      end

      # ========================================================================
      # TELEMETRY
      # ========================================================================

      defp emit_worker_telemetry(status, duration, context, result \\ nil, args \\ %{}) do
        base_metadata = %{
          worker: context.worker,
          job_id: context.job_id,
          attempt: context.attempt,
          max_attempts: context.max_attempts,
          correlation_id: context.correlation_id,
          queue: context.queue,
          priority: context.priority
        }

        # Add error_reason if present
        metadata =
          if Map.has_key?(context, :error_reason) do
            Map.put(base_metadata, :error_reason, context.error_reason)
          else
            base_metadata
          end

        # Add performance metrics
        performance_metadata = %{
          duration_ms: duration,
          throughput_per_second: if(duration > 0, do: 1000 / duration, else: 0),
          memory_usage_mb: get_memory_usage_mb()
        }

        # Merge any additional context fields (like payment_id, login_id)
        context_metadata =
          Map.take(
            context,
            [:payment_id, :login_id, :user_id, :account_id, :bank_id, :resource_id]
          )

        # Add custom telemetry metadata if implemented
        custom_metadata =
          if function_exported?(__MODULE__, :custom_telemetry_metadata, 2) do
            apply(__MODULE__, :custom_telemetry_metadata, [args, context])
          else
            %{}
          end

        # Combine all metadata
        final_metadata =
          metadata
          |> Map.merge(performance_metadata)
          |> Map.merge(context_metadata)
          |> Map.merge(custom_metadata)

        # Convert worker name to telemetry event atom
        # "PaymentWorker" -> :payment, "BankSyncWorker" -> :bank_sync
        event_name = worker_name_to_event_atom(worker_name())

        # Enhanced metrics for success cases
        metrics =
          case {status, result} do
            {:success, _} ->
              %{
                duration: duration,
                count: 1,
                success_count: 1,
                failure_count: 0
              }
            {:failure, _} ->
              %{
                duration: duration,
                count: 1,
                success_count: 0,
                failure_count: 1
              }
          end

        :telemetry.execute(
          [:ledger_bank_api, :worker, event_name, status],
          metrics,
          final_metadata
        )

        # Emit additional performance telemetry
        emit_performance_telemetry(status, duration, context, result)
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

      # Enhanced performance telemetry
      defp emit_performance_telemetry(status, duration, context, result) do
        # Emit performance metrics
        :telemetry.execute(
          [:ledger_bank_api, :worker, :performance],
          %{
            duration: duration,
            count: 1,
            status: status
          },
          %{
            worker: context.worker,
            queue: context.queue,
            priority: context.priority,
            attempt: context.attempt
          }
        )

        # Emit queue-specific metrics
        :telemetry.execute(
          [:ledger_bank_api, :worker, :queue_metrics],
          %{
            duration: duration,
            count: 1
          },
          %{
            queue: context.queue,
            priority: context.priority,
            worker: context.worker
          }
        )
      end

      # Get memory usage in MB
      defp get_memory_usage_mb do
        case :erlang.memory(:total) do
          bytes when is_integer(bytes) -> bytes / (1024 * 1024)
          _ -> 0
        end
      end

      # ========================================================================
      # ERROR HANDLING
      # ========================================================================

      defp log_worker_error(%Error{} = error, context) do
        Logger.error(
          "Worker failed",
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

      # Enhanced error handling with custom retry logic hooks
      defp handle_worker_error_with_hooks(%Error{} = error, context) do
        # Check for custom retry logic first
        custom_retry_decision =
          if function_exported?(__MODULE__, :should_retry_with_custom_logic?, 2) do
            apply(__MODULE__, :should_retry_with_custom_logic?, [error, context])
          else
            :default
          end

        case custom_retry_decision do
          {:retry, custom_delay} ->
            # Custom retry logic overrides default
            Logger.info("Worker will retry with custom delay", %{
              worker: context.worker,
              error_reason: error.reason,
              custom_delay_ms: custom_delay,
              current_attempt: context.attempt,
              max_job_attempts: context.max_attempts
            })

            # Emit custom retry telemetry
            emit_custom_retry_telemetry(error, context, custom_delay)
            {:error, error}

          {:no_retry, reason} ->
            # Custom logic says no retry
            Logger.warning("Worker will not retry (custom logic)", %{
              worker: context.worker,
              error_reason: error.reason,
              no_retry_reason: reason,
              current_attempt: context.attempt
            })

            # Emit dead-letter queue telemetry
            emit_dead_letter_telemetry(error, context)
            {:error, error}

          :default ->
            # Use default retry logic
            handle_worker_error(error, context)
        end
      end

      # Emit telemetry for custom retry decisions
      defp emit_custom_retry_telemetry(error, context, custom_delay) do
        :telemetry.execute(
          [:ledger_bank_api, :worker, :custom_retry],
          %{count: 1, delay_ms: custom_delay},
          %{
            worker: context.worker,
            job_id: context.job_id,
            error_reason: error.reason,
            error_category: error.category,
            correlation_id: context.correlation_id,
            custom_delay_ms: custom_delay
          }
        )
      end
    end
  end
end

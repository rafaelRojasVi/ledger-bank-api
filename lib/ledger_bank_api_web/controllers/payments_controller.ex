defmodule LedgerBankApiWeb.Controllers.PaymentsController do
  @moduledoc """
  Payments controller handling payment CRUD operations and processing.

  Provides endpoints for:
  - Creating payments
  - Listing payments with filtering and pagination
  - Viewing individual payments
  - Processing payments
  - Getting payment status

  Uses action fallback for centralized error handling.
  """

  use LedgerBankApiWeb.Controllers.BaseController
  alias LedgerBankApi.Financial.FinancialService
  alias LedgerBankApi.Financial.Policy, as: FinancialPolicy
  alias LedgerBankApiWeb.Validation.InputValidator

  action_fallback(LedgerBankApiWeb.FallbackController)

  @doc """
  Create a new payment.

  POST /api/payments
  Body: %{
    "amount" => "100.00",
    "direction" => "DEBIT",
    "payment_type" => "PAYMENT",
    "description" => "Payment description",
    "user_bank_account_id" => "uuid"
  }
  """
  def create(conn, params) do
    context = build_context(conn, :create_payment, %{user_id: conn.assigns.current_user.id})

    validate_and_execute(
      conn,
      context,
      InputValidator.validate_payment_creation(params),
      fn validated_params ->
        # Add user_id to validated params
        payment_params = Map.put(validated_params, :user_id, conn.assigns.current_user.id)

        # Check authorization
        if FinancialPolicy.can_create_payment?(conn.assigns.current_user, payment_params) do
          FinancialService.create_user_payment(payment_params)
        else
          {:error,
           LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
             action: :create_payment,
             user_id: conn.assigns.current_user.id
           })}
        end
      end,
      fn payment ->
        conn
        |> put_status(:created)
        |> handle_success(payment, %{action: :created})
      end
    )
  end

  @doc """
  List payments with filtering and pagination.

  GET /api/payments?page=1&page_size=20&direction=DEBIT&status=PENDING
  """
  def index(conn, params) do
    context = build_context(conn, :list_payments, %{user_id: conn.assigns.current_user.id})

    # Check authorization
    if FinancialPolicy.can_list_payments?(conn.assigns.current_user) do
      validate_and_execute(
        conn,
        context,
        InputValidator.validate_payment_filters(params),
        fn validated_params ->
          # Extract pagination and filters
          pagination = %{
            page: validated_params[:page] || 1,
            page_size: validated_params[:page_size] || 20
          }

          filters =
            validated_params
            |> Map.delete(:page)
            |> Map.delete(:page_size)

          result =
            FinancialService.list_user_payments(conn.assigns.current_user.id, %{
              filters: filters,
              pagination: pagination
            })

          case result do
            {payments, pagination} -> {:ok, {payments, pagination}}
            error -> error
          end
        end,
        fn {payments, pagination} ->
          handle_success(conn, payments, %{
            action: :listed,
            pagination: pagination
          })
        end
      )
    else
      handle_error(
        conn,
        LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
          action: :list_payments,
          user_id: conn.assigns.current_user.id
        })
      )
    end
  end

  @doc """
  Get a specific payment by ID.

  GET /api/payments/:id
  """
  def show(conn, %{"id" => id}) do
    context =
      build_context(conn, :show_payment, %{payment_id: id, user_id: conn.assigns.current_user.id})

    validate_uuid_and_get(
      conn,
      context,
      id,
      fn payment_id ->
        FinancialService.get_user_payment(payment_id)
      end,
      fn payment ->
        # Check authorization
        if FinancialPolicy.can_view_payment?(conn.assigns.current_user, payment) do
          handle_success(conn, payment, %{action: :retrieved})
        else
          {:error,
           LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
             action: :show_payment,
             payment_id: payment.id,
             user_id: conn.assigns.current_user.id
           })}
        end
      end
    )
  end

  @doc """
  Process a payment (mark as completed).

  POST /api/payments/:id/process
  """
  def process(conn, %{"id" => id}) do
    context =
      build_context(conn, :process_payment, %{
        payment_id: id,
        user_id: conn.assigns.current_user.id
      })

    validate_uuid_and_get(
      conn,
      context,
      id,
      fn payment_id ->
        FinancialService.get_user_payment(payment_id)
      end,
      fn payment ->
        # Check authorization
        if FinancialPolicy.can_process_payment?(conn.assigns.current_user, payment) do
          case FinancialService.process_payment(payment.id) do
            {:ok, updated_payment} ->
              handle_success(conn, updated_payment, %{action: :processed})

            error ->
              error
          end
        else
          {:error,
           LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
             action: :process_payment,
             payment_id: payment.id,
             user_id: conn.assigns.current_user.id
           })}
        end
      end
    )
  end

  @doc """
  Get payment status and health information.

  GET /api/payments/:id/status
  """
  def status(conn, %{"id" => id}) do
    context =
      build_context(conn, :payment_status, %{
        payment_id: id,
        user_id: conn.assigns.current_user.id
      })

    validate_uuid_and_get(
      conn,
      context,
      id,
      fn payment_id ->
        FinancialService.get_user_payment(payment_id)
      end,
      fn payment ->
        # Check authorization
        if FinancialPolicy.can_view_payment?(conn.assigns.current_user, payment) do
          # Get additional status information
          status_info = %{
            payment: payment,
            can_process: FinancialPolicy.can_process_payment?(conn.assigns.current_user, payment),
            is_duplicate:
              case FinancialService.check_duplicate_transaction(payment) do
                :ok -> false
                {:error, _} -> true
              end
          }

          handle_success(conn, status_info, %{action: :status_retrieved})
        else
          {:error,
           LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
             action: :payment_status,
             payment_id: payment.id,
             user_id: conn.assigns.current_user.id
           })}
        end
      end
    )
  end

  @doc """
  Cancel a payment (if it's still pending).

  DELETE /api/payments/:id
  """
  def delete(conn, %{"id" => id}) do
    context =
      build_context(conn, :cancel_payment, %{
        payment_id: id,
        user_id: conn.assigns.current_user.id
      })

    validate_uuid_and_get(
      conn,
      context,
      id,
      fn payment_id ->
        FinancialService.get_user_payment(payment_id)
      end,
      fn payment ->
        # Check authorization
        if FinancialPolicy.can_cancel_payment?(conn.assigns.current_user, payment) do
          # Only allow cancellation of pending payments
          case payment.status do
            "PENDING" ->
              # Update payment status to cancelled
              case payment
                   |> LedgerBankApi.Financial.Schemas.UserPayment.changeset(%{
                     status: "CANCELLED"
                   })
                   |> LedgerBankApi.Repo.update() do
                {:ok, updated_payment} ->
                  handle_success(conn, updated_payment, %{action: :cancelled})

                {:error, changeset} ->
                  handle_changeset_error(conn, changeset, context)
              end

            _ ->
              handle_error(
                conn,
                LedgerBankApi.Core.ErrorHandler.business_error(:already_processed, %{
                  payment_id: payment.id,
                  current_status: payment.status
                })
              )
          end
        else
          handle_error(
            conn,
            LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
              action: :cancel_payment,
              payment_id: payment.id,
              user_id: conn.assigns.current_user.id
            })
          )
        end
      end
    )
  end

  @doc """
  Get payment statistics for the current user.

  GET /api/payments/stats
  """
  def stats(conn, _params) do
    _context = build_context(conn, :payment_stats, %{user_id: conn.assigns.current_user.id})

    # Check authorization
    if FinancialPolicy.can_view_financial_stats?(conn.assigns.current_user) do
      # Get user's financial health
      health = FinancialService.check_user_financial_health(conn.assigns.current_user.id)

      # Get recent payments
      recent_payments =
        FinancialService.list_user_payments(conn.assigns.current_user.id, %{
          pagination: %{page: 1, page_size: 10}
        })

      stats = %{
        financial_health: health,
        recent_payments:
          case recent_payments do
            {payments, _pagination} -> payments
            _ -> []
          end
      }

      handle_success(conn, stats, %{action: :stats_retrieved})
    else
      handle_error(
        conn,
        LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
          action: :payment_stats,
          user_id: conn.assigns.current_user.id
        })
      )
    end
  end

  @doc """
  Validate a payment before creation (dry run).

  POST /api/payments/validate
  Body: %{
    "amount" => "100.00",
    "direction" => "DEBIT",
    "payment_type" => "PAYMENT",
    "description" => "Payment description",
    "user_bank_account_id" => "uuid"
  }
  """
  def validate(conn, params) do
    context = build_context(conn, :validate_payment, %{user_id: conn.assigns.current_user.id})

    validate_and_execute(
      conn,
      context,
      InputValidator.validate_payment_creation(params),
      fn validated_params ->
        # Add user_id to validated params
        payment_params = Map.put(validated_params, :user_id, conn.assigns.current_user.id)

        # Check authorization
        if FinancialPolicy.can_create_payment?(conn.assigns.current_user, payment_params) do
          # Get the account for validation
          case FinancialService.get_user_bank_account(validated_params.user_bank_account_id) do
            {:ok, account} ->
              # Create a temporary payment struct for validation
              temp_payment = %LedgerBankApi.Financial.Schemas.UserPayment{
                id: Ecto.UUID.generate(),
                user_id: conn.assigns.current_user.id,
                user_bank_account_id: validated_params.user_bank_account_id,
                amount: validated_params.amount,
                direction: validated_params.direction,
                payment_type: validated_params.payment_type,
                description: validated_params.description,
                status: "PENDING"
              }

              # Perform comprehensive validation
              case FinancialService.validate_payment_comprehensive(
                     temp_payment,
                     account,
                     conn.assigns.current_user
                   ) do
                :ok ->
                  {:ok,
                   %{
                     valid: true,
                     message: "Payment validation successful",
                     payment: temp_payment,
                     account: account
                   }}

                {:error, error} ->
                  {:ok,
                   %{
                     valid: false,
                     message: "Payment validation failed",
                     error: %{
                       reason: error.reason,
                       message: error.message,
                       code: error.code
                     },
                     payment: temp_payment,
                     account: account
                   }}
              end

            {:error, error} ->
              {:error, error}
          end
        else
          {:error,
           LedgerBankApi.Core.ErrorHandler.business_error(:insufficient_permissions, %{
             action: :validate_payment,
             user_id: conn.assigns.current_user.id
           })}
        end
      end,
      fn validation_result ->
        handle_success(conn, validation_result, %{action: :validated})
      end
    )
  end
end

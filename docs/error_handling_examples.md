# Error Handling Examples

This document provides practical examples of how to use the ErrorHandler module in your LedgerBankApi application.

## Quick Start

### For New Code (Recommended: Hybrid Approach)

```elixir
# Payment business logic
def process_payment(amount, account_id) do
  case validate_payment(amount, account_id) do
    {:ok, _} -> 
      # Process payment...
      {:ok, payment}
    {:error, :insufficient_funds} ->
      ErrorHandler.business_error(:insufficient_funds, %{
        account_id: account_id,
        available_balance: get_balance(account_id),
        requested_amount: amount
      })
    {:error, :daily_limit_exceeded} ->
      ErrorHandler.business_error(:daily_limit_exceeded, %{
        account_id: account_id,
        daily_limit: get_daily_limit(account_id),
        amount_used_today: get_daily_usage(account_id)
      })
  end
end

# Authentication business logic
def authenticate_user(token) do
  case validate_token(token) do
    {:ok, user} -> {:ok, user}
    {:error, :token_expired} ->
      ErrorHandler.business_error(:token_expired, %{
        token_id: extract_token_id(token),
        expired_at: get_token_expiry(token)
      })
    {:error, :invalid_token} ->
      ErrorHandler.business_error(:invalid_token, %{
        token_type: get_token_type(token)
      })
  end
end
```

### For Existing Code (Legacy Approach - Still Supported)

```elixir
# Existing code continues to work unchanged
def existing_payment_logic(amount, account_id) do
  case validate_payment(amount, account_id) do
    {:ok, _} -> {:ok, payment}
    {:error, :insufficient_funds} ->
      ErrorHandler.handle_common_error(:insufficient_funds, %{action: :process_payment})
  end
end
```

## Response Structure Comparison

### Legacy Approach Response
```elixir
%{
  error: %{
    type: :insufficient_funds,
    code: 422,
    message: "Insufficient funds for this transaction",
    details: %{context: %{action: :process_payment}}
  }
}
```

### Hybrid Approach Response
```elixir
%{
  error: %{
    type: :unprocessable_entity,
    code: 422,
    message: "Insufficient funds for this transaction",
    details: %{
      reason: :insufficient_funds,
      account_id: "acc_123",
      available_balance: 50.00,
      requested_amount: 100.00,
      context: %{action: :process_payment}
    }
  }
}
```

## Pattern Matching Examples

### Controller Error Handling

```elixir
defmodule LedgerBankApiWeb.PaymentController do
  def create(conn, params) do
    case PaymentService.create_payment(params) do
      {:ok, payment} ->
        json(conn, %{data: payment})
      
      {:error, %{error: %{type: :unprocessable_entity, details: %{reason: :insufficient_funds}}}} ->
        conn
        |> put_status(422)
        |> json(%{error: "Payment failed: insufficient funds"})
      
      {:error, %{error: %{type: :validation_error, details: %{reason: :invalid_amount_format}}}} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid amount format"})
      
      {:error, error_response} ->
        conn
        |> put_status(error_response.error.code)
        |> json(error_response)
    end
  end
end
```

### Business Logic Error Handling

```elixir
defmodule LedgerBankApi.Banking.PaymentService do
  def create_payment(params) do
    with {:ok, amount} <- validate_amount(params.amount),
         {:ok, account} <- get_account(params.account_id),
         {:ok, _} <- check_balance(account, amount) do
      # Create payment...
      {:ok, payment}
    else
      {:error, :invalid_amount_format} ->
        ErrorHandler.business_error(:invalid_amount_format, %{
          field: "amount",
          value: params.amount,
          expected_format: "decimal"
        })
      
      {:error, :account_not_found} ->
        ErrorHandler.business_error(:account_not_found, %{
          account_id: params.account_id
        })
      
      {:error, :insufficient_funds} ->
        ErrorHandler.business_error(:insufficient_funds, %{
          account_id: params.account_id,
          available: account.balance,
          requested: amount
        })
    end
  end
end
```

## Migration Guide

### Step 1: Start Using Hybrid Approach for New Features

When adding new business logic, use the hybrid approach:

```elixir
# Instead of adding new error atoms, use:
ErrorHandler.business_error(:new_business_rule, %{context: "data"})
```

### Step 2: Gradually Migrate Existing Code

When you need to modify existing error handling code, migrate to the hybrid approach:

```elixir
# Before (Legacy)
ErrorHandler.handle_common_error(:insufficient_funds, %{action: :payment})

# After (Hybrid)
ErrorHandler.business_error(:insufficient_funds, %{action: :payment})
```

### Step 3: Update Pattern Matching

Update your pattern matching to use the new structure:

```elixir
# Before (Legacy)
case result do
  %{error: %{type: :insufficient_funds}} -> # Handle insufficient funds
end

# After (Hybrid)
case result do
  %{error: %{type: :unprocessable_entity, details: %{reason: :insufficient_funds}}} -> # Handle insufficient funds
end
```

## Benefits of Hybrid Approach

1. **Consistent HTTP Status Codes**: All business rule violations return 422, validation errors return 400, etc.
2. **Rich Context**: Additional details are preserved in the response
3. **Elixir-Idiomatic**: Follows Elixir's preference for simple atom sets + structured data
4. **Maintainable**: No need to add new error atoms for every business rule
5. **Extensible**: Easy to add new business reasons without code changes
6. **Backward Compatible**: Existing code continues to work unchanged

## Best Practices

1. **Use hybrid approach for new code**
2. **Keep legacy approach for existing code until you need to modify it**
3. **Include relevant context in additional_details**
4. **Use consistent error messages**
5. **Test both error types and business reasons**
6. **Document business error reasons in your domain modules**

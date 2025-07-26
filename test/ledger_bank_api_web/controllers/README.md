# Web Layer Testing Documentation

This directory contains comprehensive tests for the LedgerBankApi web layer, covering all controllers, authentication, authorization, and business logic integration.

## Test Structure

### Controller Tests

Each controller has its own comprehensive test file:

- **`auth_controller_test.exs`** - Authentication endpoints (register, login, refresh, logout, me)
- **`users_controller_test.exs`** - User management endpoints (CRUD operations, role-based access)
- **`banking_controller_test.exs`** - Banking operations (accounts, transactions, balances, sync)
- **`payments_controller_test.exs`** - Payment management (CRUD operations, processing)
- **`user_bank_logins_controller_test.exs`** - Bank login management (CRUD operations, sync)
- **`health_controller_test.exs`** - Health check endpoints (basic, detailed, ready, live)
- **`controllers_test.exs`** - Integration tests for the entire web layer

### Test Helpers

- **`../support/auth_helpers.ex`** - Authentication utilities for tests
- **`../support/conn_case.ex`** - Base test case with database setup

## Running Tests

### Run All Web Layer Tests

```bash
# Run all controller tests
mix test test/ledger_bank_api_web/controllers/

# Run with verbose output
mix test test/ledger_bank_api_web/controllers/ --trace

# Run with coverage
mix test test/ledger_bank_api_web/controllers/ --cover
```

### Run Individual Controller Tests

```bash
# Auth controller tests
mix test test/ledger_bank_api_web/controllers/auth_controller_test.exs

# Users controller tests
mix test test/ledger_bank_api_web/controllers/users_controller_test.exs

# Banking controller tests
mix test test/ledger_bank_api_web/controllers/banking_controller_test.exs

# Payments controller tests
mix test test/ledger_bank_api_web/controllers/payments_controller_test.exs

# User bank logins controller tests
mix test test/ledger_bank_api_web/controllers/user_bank_logins_controller_test.exs

# Health controller tests
mix test test/ledger_bank_api_web/controllers/health_controller_test.exs
```

### Run Integration Tests

```bash
# Run the comprehensive integration test suite
mix test test/ledger_bank_api_web/controllers/controllers_test.exs
```

## Test Coverage

### Authentication & Authorization

- ✅ User registration with validation
- ✅ User login with JWT token generation
- ✅ Token refresh functionality
- ✅ User logout with token revocation
- ✅ Profile access with authentication
- ✅ Role-based access control (admin vs user)
- ✅ Suspended user handling
- ✅ Invalid token handling

### User Management

- ✅ CRUD operations for users
- ✅ Admin-only user listing
- ✅ User profile updates (self and admin)
- ✅ User suspension/activation
- ✅ Role-based user filtering
- ✅ Authorization checks for user operations

### Banking Operations

- ✅ Account listing and details
- ✅ Transaction history with pagination
- ✅ Account balance retrieval
- ✅ Payment history
- ✅ Bank sync operations
- ✅ User isolation (users can only access their own data)
- ✅ Pagination, filtering, and sorting

### Payment Management

- ✅ Payment CRUD operations
- ✅ Payment processing workflow
- ✅ Account-specific payment listing
- ✅ Payment validation (types, amounts, statuses)
- ✅ Payment status management
- ✅ Background job integration

### Bank Login Management

- ✅ Bank login CRUD operations
- ✅ Sync frequency management
- ✅ Login status management
- ✅ Security (password not exposed in responses)
- ✅ Unique constraint validation
- ✅ Cascade deletion handling

### Health Checks

- ✅ Basic health status
- ✅ Detailed health with service checks
- ✅ Readiness checks
- ✅ Liveness checks
- ✅ Performance metrics
- ✅ Concurrent request handling

## Test Features

### Authentication Helpers

The test suite includes comprehensive authentication helpers:

```elixir
# Create and authenticate a user
{user, access_token, conn} = setup_authenticated_user(conn)

# Create and authenticate an admin
{admin, access_token, conn} = setup_authenticated_admin(conn)

# Create test users with specific roles
{:ok, user} = create_user_with_role("user", %{email: "user@example.com"})
```

### Database Setup

Tests use Ecto SQL Sandbox for isolated database transactions:

- Each test runs in its own transaction
- Database is rolled back after each test
- No test interference between runs

### Error Handling

All tests verify proper error handling:

- Validation errors (400)
- Authentication errors (401)
- Authorization errors (403)
- Not found errors (404)
- Conflict errors (409)

### Response Format Validation

Tests verify consistent API response formats:

- Standardized success responses
- Consistent error response structure
- Proper HTTP status codes
- JSON response validation

## Test Data Management

### Fixtures

Each test creates its own test data:

```elixir
# Create test banks and branches
{:ok, bank} = create_bank(@valid_bank_attrs)
{:ok, bank_branch} = create_bank_branch(Map.put(@valid_bank_branch_attrs, "bank_id", bank.id))

# Create user bank accounts
{:ok, account} = create_user_bank_account(Map.merge(@valid_user_bank_account_attrs, %{
  "user_bank_login_id" => login.id
}))
```

### Cleanup

- Database is automatically cleaned up after each test
- No manual cleanup required
- Tests are isolated and independent

## Performance Considerations

### Test Speed

- Tests are designed to run quickly
- Database operations are optimized
- Minimal external dependencies
- Parallel test execution where possible

### Resource Usage

- Tests use minimal memory
- Database connections are pooled efficiently
- Background jobs are mocked where appropriate

## Continuous Integration

### CI/CD Integration

These tests are designed to run in CI/CD pipelines:

```yaml
# Example GitHub Actions configuration
- name: Run Web Layer Tests
  run: mix test test/ledger_bank_api_web/controllers/
```

### Test Reporting

Tests provide clear feedback:

- Detailed error messages
- Stack traces for failures
- Coverage reports
- Performance metrics

## Debugging Tests

### Common Issues

1. **Database Connection Errors**
   - Ensure PostgreSQL is running
   - Check database configuration
   - Verify migrations are up to date

2. **Authentication Failures**
   - Check JWT configuration
   - Verify secret keys are set
   - Ensure test environment is properly configured

3. **Test Isolation Issues**
   - Ensure tests are not sharing state
   - Check for proper database cleanup
   - Verify test order independence

### Debugging Commands

```bash
# Run single test with detailed output
mix test test/ledger_bank_api_web/controllers/auth_controller_test.exs:25 --trace

# Run tests with IEx debugging
iex -S mix test test/ledger_bank_api_web/controllers/auth_controller_test.exs

# Check test coverage
mix test test/ledger_bank_api_web/controllers/ --cover
```

## Best Practices

### Writing New Tests

1. **Follow the existing pattern**
   - Use the same structure as existing tests
   - Include both positive and negative test cases
   - Test error conditions thoroughly

2. **Use descriptive test names**
   - Test names should clearly describe what is being tested
   - Include expected behavior in the name

3. **Test one thing at a time**
   - Each test should focus on a single behavior
   - Avoid complex test scenarios

4. **Use proper setup and teardown**
   - Use `setup` blocks for common test data
   - Ensure tests are independent

### Maintaining Tests

1. **Keep tests up to date**
   - Update tests when API changes
   - Maintain test data consistency
   - Review test coverage regularly

2. **Refactor when needed**
   - Extract common test utilities
   - Remove duplicate test code
   - Improve test readability

3. **Monitor test performance**
   - Track test execution time
   - Optimize slow tests
   - Maintain test isolation

## Contributing

When adding new controllers or modifying existing ones:

1. **Add comprehensive tests**
   - Cover all endpoints
   - Test error conditions
   - Verify authorization

2. **Update this documentation**
   - Add new test files to the list
   - Update running instructions
   - Document new test helpers

3. **Ensure test coverage**
   - Aim for 100% coverage of controller logic
   - Test edge cases and error conditions
   - Verify integration with business logic

## Support

For questions about the test suite:

1. Check the test files for examples
2. Review the authentication helpers
3. Examine existing test patterns
4. Consult the main project documentation 
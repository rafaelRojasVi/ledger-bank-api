# LedgerBankApi Business Model & Architecture

## Overview
LedgerBankApi is a modular, extensible banking API system designed for robust, testable, and maintainable financial integrations. It supports multiple banks, user logins, accounts, transactions, and payments, with a focus on clean separation of concerns, background job processing, and integration with external bank APIs.

---

## Core Schemas & Relationships

### 1. **Bank**
- Represents a financial institution.
- Fields: `name`, `country`, `logo_url`, `api_endpoint`, `status`, `integration_module` (the Elixir module for integration).
- Has many `BankBranch`es.

### 2. **BankBranch**
- Represents a branch of a bank.
- Fields: `name`, `iban`, `country`, `routing_number`, `swift_code`, `bank_id` (FK).
- Has many `UserBankLogin`s.

### 3. **User**
- Represents an application user.
- Fields: `email`, `full_name`, `status`.
- Has many `UserBankLogin`s.

### 4. **UserBankLogin**
- Represents a user's login to a specific bank branch.
- Fields: `user_id` (FK), `bank_branch_id` (FK), `username`, `encrypted_password`, `status`, `last_sync_at`, `sync_frequency`.
- Has many `UserBankAccount`s.

### 5. **UserBankAccount**
- Represents a user's account at a bank.
- Fields: `user_bank_login_id` (FK), `currency`, `account_type`, `balance`, `last_four`, `account_name`, `status`, `last_sync_at`, `external_account_id`.
- Has many `UserPayment`s and `Transaction`s.

### 6. **UserPayment**
- Represents a payment or transfer initiated by a user.
- Fields: `user_bank_account_id` (FK), `amount`, `description`, `payment_type`, `status`, `posted_at`, `external_transaction_id`.

### 7. **Transaction**
- Represents a financial transaction on a user account.
- Fields: `account_id` (FK to `UserBankAccount`), `description`, `amount`, `posted_at`.

---

## Business Logic & Contexts

- Each resource (bank, branch, login, account, payment, transaction) has its own module in `lib/ledger_bank_api/banking/` (e.g., `banks.ex`, `user_bank_logins.ex`).
- These modules use a `CrudHelpers` macro for standard CRUD and can be extended with custom logic.
- The main context (`context.ex`) delegates to these modules, acting as a facade for the rest of the app.
- All business logic is tested with ExUnit, and foreign key constraints are respected in all tests.

---

## API Structure & Data Flow

### **How Data Flows**
1. **User creates a bank login** via the API (providing credentials, selecting a bank/branch).
2. **A background job** (`BankSyncWorker`) is enqueued to sync accounts and transactions for that login.
3. **The worker fetches data** from the correct integration module (e.g., `MonzoClient`), using the `integration_module` field on the bank.
4. **Fetched data is mapped** to internal schemas and upserted into the database.
5. **API endpoints** allow users to fetch their accounts, transactions, balances, and payments.

### **API Endpoints (example)**
- `POST /api/bank_logins` — Create a new bank login (triggers sync job)
- `GET /api/accounts` — List all user bank accounts
- `GET /api/accounts/:id/transactions` — List transactions for an account
- `GET /api/accounts/:id/payments` — List payments for an account
- `POST /api/sync/:login_id` — Manually trigger a sync for a login

### **What is Needed to Fetch Data?**
- **User must have a valid login** (with credentials) for a bank branch.
- **Bank must have a valid integration module** (e.g., Monzo, Plaid, etc.).
- **Sync jobs** use the login credentials and integration module to fetch and update data.
- **API endpoints** query the database for the user’s accounts, transactions, and payments.

---

## Integration Modules

- Each bank integration implements the `BankApiClient` behaviour:
  - `fetch_accounts/1`
  - `fetch_transactions/2`
  - `fetch_balance/2`
- The integration module is dynamically selected at runtime using the `integration_module` field on the bank.
- Integrations use a generic mapping helper to translate external API data to internal schema fields.
- Mimic is used in tests to mock integration modules and isolate tests from real HTTP calls.

---

## Background Jobs & Workers

- **Oban** is used for background job processing.
- `BankSyncWorker` is responsible for syncing accounts and transactions for a user login.
- Jobs are enqueued using the worker’s `.new/2` function and `Oban.insert/1`.
- Workers use the error handler for consistent error handling and logging.

---

## Error Handling

- A shared `ErrorHandler` behaviour provides:
  - Standardized error responses
  - Logging
  - Wrapping of business logic for consistent error handling in workers and controllers

---

## Testing

- **Unit tests** for each business module, ensuring CRUD and custom logic work and all foreign key constraints are respected.
- **Integration tests** for workflows (e.g., syncing a login end-to-end).
- **Controller/API tests** for endpoint coverage.
- **Mimic** is used to mock external integrations in worker and integration tests.
- **Test DB** is set up and migrated before running tests; all parent records are inserted in test setup to satisfy constraints.

---

## Example Data Flow: Fetching Transactions for a User
1. User logs in and creates a bank login via the API.
2. The system enqueues a sync job for that login.
3. The worker fetches accounts and transactions from the bank’s integration module.
4. Data is mapped and upserted into the database.
5. User calls `GET /api/accounts/:id/transactions` to view their transactions.
6. The API queries the DB and returns the transactions for that account.

---

## Summary Table: Module Responsibilities

| Module/File                        | Responsibility                                      |
|------------------------------------|-----------------------------------------------------|
| `bank.ex`                          | Bank schema                                         |
| `bank_branches.ex`                 | Bank branch business logic                          |
| `user_bank_logins.ex`              | User bank login business logic                      |
| `user_bank_accounts.ex`            | User bank account business logic                    |
| `user_payments.ex`                 | User payment business logic                         |
| `transactions.ex`                  | Transaction business logic                          |
| `context.ex`                       | Facade, delegates to resource modules               |
| `bank_api_client.ex`               | Integration behaviour contract                      |
| `monzo_client.ex`                  | Monzo integration implementation                    |
| `bank_sync_worker.ex`              | Oban worker for syncing logins                      |
| `error_handler.ex`                 | Standardized error handling                         |
| `crud_helpers.ex`                  | Macro for DRY CRUD logic                            |
| `test/ledger_bank_api/banking/`    | Unit tests for each business module                 |
| `test/ledger_bank_api/banking/workers/` | Worker and integration tests using Mimic         |

---

## Testing & Change Log

- All core resource tests pass (banks, branches, logins, accounts, payments, transactions).
- All foreign key constraints are respected in tests.
- Mimic is used to mock integrations in worker tests.
- Oban job enqueue logic uses `.new/2` API.
- Migrations are up to date for all required columns.
- See `test/` directory for detailed test coverage.

---

## Next Steps
- Expand integration and controller tests.
- Add factories/helpers for DRY test setup.
- Continue documenting errors, fixes, and new features in this file.

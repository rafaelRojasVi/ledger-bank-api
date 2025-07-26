# LedgerBankApi - API Documentation

## Overview

LedgerBankApi is a modern banking API that provides secure access to financial data, user management, and payment processing. The API uses JWT authentication and follows RESTful principles.

## Base URL

- **Development**: `http://localhost:4000`
- **Production**: `https://your-domain.com`

## Authentication

The API uses JWT (JSON Web Tokens) for authentication. Most endpoints require a valid access token in the Authorization header:

```
Authorization: Bearer <access_token>
```

### Token Types

- **Access Token**: Short-lived (15 minutes), used for API requests
- **Refresh Token**: Long-lived (7 days), used to get new access tokens

## Public Endpoints

### Health Check

```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-27T10:30:00Z",
  "version": "0.1.0",
  "checks": {
    "database": "ok",
    "external_api": "ok"
  }
}
```

## Authentication Endpoints

### Register User

```http
POST /api/auth/register
Content-Type: application/json

{
  "user": {
    "email": "user@example.com",
    "full_name": "John Doe",
    "password": "securepassword123",
    "role": "user"
  }
}
```

**Response:**
```json
{
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "user",
      "status": "ACTIVE"
    },
    "access_token": "jwt_token",
    "refresh_token": "jwt_refresh_token"
  },
  "message": "User registered successfully"
}
```

### Login

```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Response:**
```json
{
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "user",
      "status": "ACTIVE"
    },
    "access_token": "jwt_token",
    "refresh_token": "jwt_refresh_token"
  },
  "message": "Login successful"
}
```

### Refresh Token

```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "jwt_refresh_token"
}
```

**Response:**
```json
{
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "user",
      "status": "ACTIVE"
    },
    "access_token": "new_jwt_token",
    "refresh_token": "new_jwt_refresh_token"
  },
  "message": "Tokens refreshed successfully"
}
```

## Protected Endpoints

All endpoints below require authentication via the `Authorization: Bearer <token>` header.

### User Profile

#### Get Current User

```http
GET /api/me
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "full_name": "John Doe",
    "role": "user",
    "status": "ACTIVE",
    "created_at": "2025-01-27T10:30:00Z",
    "updated_at": "2025-01-27T10:30:00Z"
  }
}
```

#### Logout

```http
POST /api/logout
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "message": "Logout successful",
  "data": {}
}
```

### User Management (Admin Only)

#### List Users

```http
GET /api/users
Authorization: Bearer <admin_token>
```

#### Get User by ID

```http
GET /api/users/{user_id}
Authorization: Bearer <admin_token>
```

#### Update User

```http
PUT /api/users/{user_id}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "user": {
    "full_name": "Updated Name",
    "email": "updated@example.com"
  }
}
```

#### Suspend User

```http
POST /api/users/{user_id}/suspend
Authorization: Bearer <admin_token>
```

#### Activate User

```http
POST /api/users/{user_id}/activate
Authorization: Bearer <admin_token>
```

#### List Users by Role

```http
GET /api/users/role/{role}
Authorization: Bearer <admin_token>
```

### User Bank Logins

#### List Bank Logins

```http
GET /api/user-bank-logins
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "username": "bank_username",
      "status": "ACTIVE",
      "last_sync_at": "2025-01-27T10:30:00Z",
      "sync_frequency": 3600,
      "bank_branch": {
        "id": "uuid",
        "name": "Main Branch",
        "bank": {
          "id": "uuid",
          "name": "Demo Bank",
          "country": "US"
        }
      },
      "created_at": "2025-01-27T10:30:00Z",
      "updated_at": "2025-01-27T10:30:00Z"
    }
  ]
}
```

#### Get Bank Login

```http
GET /api/user-bank-logins/{login_id}
Authorization: Bearer <access_token>
```

#### Create Bank Login

```http
POST /api/user-bank-logins
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "user_bank_login": {
    "bank_branch_id": "uuid",
    "username": "bank_username",
    "encrypted_password": "encrypted_password"
  }
}
```

#### Update Bank Login

```http
PUT /api/user-bank-logins/{login_id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "user_bank_login": {
    "username": "new_username",
    "sync_frequency": 7200
  }
}
```

#### Delete Bank Login

```http
DELETE /api/user-bank-logins/{login_id}
Authorization: Bearer <access_token>
```

#### Sync Bank Login

```http
POST /api/user-bank-logins/{login_id}/sync
Authorization: Bearer <access_token>
```

### Banking

#### List Accounts

```http
GET /api/accounts
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Checking Account",
      "status": "ACTIVE",
      "type": "CHECKING",
      "currency": "USD",
      "institution": {
        "id": "uuid",
        "name": "Demo Bank"
      },
      "last_four": "1234",
      "balance": "1000.00",
      "last_sync_at": "2025-01-27T10:30:00Z",
      "links": {
        "self": "/api/accounts/uuid",
        "transactions": "/api/accounts/uuid/transactions",
        "balances": "/api/accounts/uuid/balances",
        "payments": "/api/accounts/uuid/payments"
      }
    }
  ]
}
```

#### Get Account

```http
GET /api/accounts/{account_id}
Authorization: Bearer <access_token>
```

#### Get Account Transactions

```http
GET /api/accounts/{account_id}/transactions
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `page_size` (optional): Items per page (default: 20, max: 100)
- `date_from` (optional): Filter from date (ISO8601)
- `date_to` (optional): Filter to date (ISO8601)
- `sort_by` (optional): Sort field (posted_at, amount, description)
- `sort_order` (optional): Sort direction (asc, desc)

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "account_id": "uuid",
      "description": "Grocery Store",
      "amount": "50.00",
      "posted_at": "2025-01-27T10:30:00Z",
      "type": "transaction"
    }
  ],
  "account": {
    "id": "uuid",
    "name": "Checking Account",
    "status": "ACTIVE",
    "type": "CHECKING",
    "currency": "USD",
    "institution": {
      "id": "uuid",
      "name": "Demo Bank"
    },
    "last_four": "1234",
    "balance": "1000.00",
    "last_sync_at": "2025-01-27T10:30:00Z"
  }
}
```

#### Get Account Balances

```http
GET /api/accounts/{account_id}/balances
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": {
    "account_id": "uuid",
    "balance": "1000.00",
    "currency": "USD",
    "last_updated": "2025-01-27T10:30:00Z"
  }
}
```

#### Get Account Payments

```http
GET /api/accounts/{account_id}/payments
Authorization: Bearer <access_token>
```

### Payments

#### List Payments

```http
GET /api/payments
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "amount": "100.00",
      "direction": "DEBIT",
      "description": "Payment to John",
      "payment_type": "TRANSFER",
      "status": "COMPLETED",
      "posted_at": "2025-01-27T10:30:00Z",
      "external_transaction_id": "ext_123",
      "user_bank_account": {
        "id": "uuid",
        "account_name": "Checking Account",
        "last_four": "1234",
        "currency": "USD"
      },
      "created_at": "2025-01-27T10:30:00Z",
      "updated_at": "2025-01-27T10:30:00Z"
    }
  ]
}
```

#### Get Payment

```http
GET /api/payments/{payment_id}
Authorization: Bearer <access_token>
```

#### Create Payment

```http
POST /api/payments
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "payment": {
    "user_bank_account_id": "uuid",
    "amount": "100.00",
    "direction": "DEBIT",
    "description": "Payment to John",
    "payment_type": "TRANSFER"
  }
}
```

#### Update Payment

```http
PUT /api/payments/{payment_id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "payment": {
    "description": "Updated description",
    "amount": "150.00"
  }
}
```

#### Delete Payment

```http
DELETE /api/payments/{payment_id}
Authorization: Bearer <access_token>
```

#### Process Payment

```http
POST /api/payments/{payment_id}/process
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "message": "Payment processing initiated",
  "payment_id": "uuid",
  "status": "queued"
}
```

#### List Payments for Account

```http
GET /api/payments/account/{account_id}
Authorization: Bearer <access_token>
```

### Bank Sync

#### Sync Bank Data

```http
POST /api/sync/{login_id}
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "message": "Bank sync initiated",
  "login_id": "uuid",
  "status": "queued"
}
```

## Error Responses

All endpoints return consistent error responses:

```json
{
  "error": {
    "type": "error_type",
    "message": "Human readable error message",
    "code": 400,
    "details": {},
    "timestamp": "2025-01-27T10:30:00Z"
  }
}
```

### Common Error Types

- `validation_error` (400): Invalid input data
- `unauthorized` (401): Authentication required or invalid
- `forbidden` (403): Insufficient permissions
- `not_found` (404): Resource not found
- `conflict` (409): Resource conflict
- `rate_limit_exceeded` (429): Too many requests
- `internal_server_error` (500): Server error

## Rate Limiting

The API implements rate limiting:
- **Limit**: 100 requests per minute per IP address
- **Headers**: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`

## User Roles

- **user**: Standard user with access to their own data
- **admin**: Administrative user with access to all data
- **support**: Support user with limited administrative access

## Data Models

### User
```json
{
  "id": "uuid",
  "email": "string",
  "full_name": "string",
  "role": "user|admin|support",
  "status": "ACTIVE|SUSPENDED",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### User Bank Login
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "bank_branch_id": "uuid",
  "username": "string",
  "status": "ACTIVE|INACTIVE|ERROR",
  "last_sync_at": "datetime",
  "sync_frequency": "integer"
}
```

### User Bank Account
```json
{
  "id": "uuid",
  "user_bank_login_id": "uuid",
  "currency": "string",
  "account_type": "CHECKING|SAVINGS|CREDIT|INVESTMENT",
  "balance": "decimal",
  "last_four": "string",
  "account_name": "string",
  "status": "ACTIVE|INACTIVE|CLOSED",
  "last_sync_at": "datetime",
  "external_account_id": "string"
}
```

### Transaction
```json
{
  "id": "uuid",
  "account_id": "uuid",
  "description": "string",
  "amount": "decimal",
  "direction": "CREDIT|DEBIT",
  "posted_at": "datetime"
}
```

### User Payment
```json
{
  "id": "uuid",
  "user_bank_account_id": "uuid",
  "amount": "decimal",
  "direction": "CREDIT|DEBIT",
  "description": "string",
  "payment_type": "TRANSFER|PAYMENT|DEPOSIT|WITHDRAWAL",
  "status": "PENDING|COMPLETED|FAILED|CANCELLED",
  "posted_at": "datetime",
  "external_transaction_id": "string"
}
```

## Testing

You can test the API using tools like:
- [Postman](https://www.postman.com/)
- [curl](https://curl.se/)
- [Insomnia](https://insomnia.rest/)

### Example curl commands

```bash
# Health check
curl http://localhost:4000/api/health

# Register user
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"test@example.com","full_name":"Test User","password":"password123"}}'

# Login
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Get accounts (with token)
curl http://localhost:4000/api/accounts \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
``` 
# LedgerBankApi - API Documentation

## 📖 Overview

LedgerBankApi provides comprehensive OpenAPI (Swagger) documentation for all endpoints, request/response schemas, and authentication mechanisms.

## 🚀 Quick Start

### Access Documentation

1. **Interactive Swagger UI**: http://localhost:4000/api/docs
2. **Simple HTML Documentation**: http://localhost:4000/api/docs/simple
3. **OpenAPI JSON Specification**: http://localhost:4000/api/swagger.json

### Generate Documentation

```bash
# Generate OpenAPI specification
mix swagger.generate

# Validate OpenAPI specification
mix swagger.validate

# Or use aliases
mix docs.generate
mix docs.validate
```

## 🔧 Setup & Configuration

### Dependencies

The following dependencies are included for OpenAPI documentation:

- `open_api_spex` - OpenAPI 3.0 specification library
- `phoenix_swagger` - Phoenix integration for Swagger

### Configuration

OpenAPI configuration is set in `config/config.exs`:

```elixir
# Configure OpenApiSpex
config :ledger_bank_api, :open_api_spex,
  title: "LedgerBankApi",
  version: "1.0.0",
  description: "A modern Elixir/Phoenix API for banking and financial data management",
  server_url: "http://localhost:4000"
```

## 📋 API Endpoints

### Health Check
- `GET /api/health` - Service health check

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - User logout
- `POST /api/auth/logout-all` - Logout all devices
- `GET /api/auth/me` - Get current user
- `GET /api/auth/validate` - Validate access token

### User Management
- `GET /api/users` - List users (with pagination/filtering)
- `POST /api/users` - Create user
- `GET /api/users/{id}` - Get user by ID
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Delete user
- `GET /api/users/stats` - Get user statistics

## 🔐 Authentication

### JWT Bearer Token

All protected endpoints require a JWT Bearer token in the Authorization header:

```
Authorization: Bearer <your_access_token>
```

### Token Types

- **Access Token**: Expires in 15 minutes
- **Refresh Token**: Expires in 7 days

### Authentication Flow

1. Login with email/password → Receive access + refresh tokens
2. Use access token for API requests
3. When access token expires, use refresh token to get new access token
4. Logout by revoking refresh token

## 📊 Response Format

### Success Response

```json
{
  "data": { ... },
  "success": true,
  "timestamp": "2024-01-15T10:30:00Z",
  "correlation_id": "req_1234567890abcdef",
  "metadata": { ... }
}
```

### Error Response

```json
{
  "error": {
    "type": "validation_error",
    "message": "Invalid email format",
    "code": 400,
    "reason": "invalid_email_format",
    "details": { ... },
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

## 🎯 Error Categories

| Category | HTTP Code | Description |
|----------|-----------|-------------|
| `validation_error` | 400 | Input validation failures |
| `not_found` | 404 | Resource not found |
| `unauthorized` | 401 | Authentication failures |
| `forbidden` | 403 | Authorization failures |
| `conflict` | 409 | Resource conflicts |
| `unprocessable_entity` | 422 | Business rule violations |
| `service_unavailable` | 503 | External service failures |
| `internal_server_error` | 500 | Internal system errors |

## 📝 Request/Response Schemas

### User Schema

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "email": "user@example.com",
  "full_name": "John Doe",
  "role": "user",
  "status": "ACTIVE",
  "active": true,
  "verified": false,
  "inserted_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

### Login Request

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

### Login Response

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": { ... }
}
```

## 🔄 Pagination

List endpoints support pagination with the following parameters:

- `page` - Page number (default: 1, minimum: 1)
- `page_size` - Items per page (default: 20, maximum: 100)

Example: `GET /api/users?page=2&page_size=50`

## 🔍 Filtering & Sorting

### Filtering

Filter by specific fields:
- `status` - User status (ACTIVE, SUSPENDED, DELETED)
- `role` - User role (user, admin, support)

Example: `GET /api/users?status=ACTIVE&role=admin`

### Sorting

Sort by fields with direction:
- Format: `field:direction`
- Directions: `asc`, `desc`
- Multiple sorts: comma-separated

Example: `GET /api/users?sort=email:asc,name:desc`

## 🛠️ Development

### Adding New Endpoints

1. **Update Swagger Specification**: Add new schemas and paths in `lib/ledger_bank_api_web/swagger.ex`
2. **Add Controller Actions**: Implement the endpoint logic
3. **Update Router**: Add routes in `lib/ledger_bank_api_web/router.ex`
4. **Generate Documentation**: Run `mix swagger.generate`
5. **Validate**: Run `mix swagger.validate`

### Schema Guidelines

- Use descriptive field names and descriptions
- Include examples for all fields
- Specify required fields
- Use appropriate data types and formats
- Include validation constraints (min/max length, enums, etc.)

### Testing Documentation

1. Start the server: `mix phx.server`
2. Visit: http://localhost:4000/api/docs
3. Test endpoints using the "Try it out" feature
4. Verify request/response schemas match implementation

## 📚 Additional Resources

- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Swagger UI Documentation](https://swagger.io/tools/swagger-ui/)
- [OpenApiSpex Documentation](https://hexdocs.pm/open_api_spex/)

## 🐛 Troubleshooting

### Common Issues

1. **Documentation not loading**: Ensure `mix swagger.generate` has been run
2. **Invalid JSON**: Run `mix swagger.validate` to check for errors
3. **Missing endpoints**: Verify routes are added to both router and swagger spec
4. **Authentication issues**: Check that Bearer token is properly formatted

### Validation Errors

Run `mix swagger.validate` to check for:
- Missing required fields
- Invalid schema definitions
- Broken references
- Malformed JSON

## 📞 Support

For API documentation issues:
- Check the interactive docs: http://localhost:4000/api/docs
- Validate specification: `mix swagger.validate`
- Review this documentation
- Contact: support@ledgerbankapi.com

# Changelog

## [Unreleased] - 2024-07-21 (Sunday)

### Added
- **JWT Authentication**: Support for both access and refresh tokens, with user roles included in JWT claims.
- **Centralized Error Handling**: Introduced a unified error handling mechanism for payment processing and bank synchronization workers.
- **New Macros**: Added macros for unique constraints, required fields, and validations to improve schema and changeset definitions.

### Changed
- **JWT Configuration**: Updated for improved token management and security.
- **CRUD Helpers**: Refactored for better struct creation and validation.
- **User Roles**: User roles are now included in authentication and authorization flows.
- **Tests**: Updated to reflect changes in user roles, payment directions, and bank details.

### Removed
- Deprecated or redundant code in workers and helpers as part of the refactor.

---

See the README.md for full usage and architecture details. 
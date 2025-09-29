defmodule LedgerBankApiWeb.ApiDocsController do
  @moduledoc """
  API Documentation controller for serving OpenAPI/Swagger documentation.

  Provides endpoints for:
  - OpenAPI specification
  - Swagger UI
  - API documentation
  """

  use LedgerBankApiWeb, :controller

  @doc """
  Serve the OpenAPI specification.
  """
  def openapi_spec(conn, _params) do
    spec = %{
      openapi: "3.0.0",
      info: %{
        title: "LedgerBank API",
        description: "A comprehensive banking API with user management, authentication, and financial operations.",
        version: "1.0.0",
        contact: %{
          name: "API Support",
          email: "support@ledgerbank.com"
        },
        license: %{
          name: "MIT",
          url: "https://opensource.org/licenses/MIT"
        }
      },
      servers: [
        %{
          url: "http://localhost:4000/api",
          description: "Development server"
        },
        %{
          url: "https://api.ledgerbank.com/api",
          description: "Production server"
        }
      ],
      paths: get_api_paths(),
      components: %{
        securitySchemes: %{
          bearerAuth: %{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          }
        },
        schemas: get_api_schemas()
      },
      security: [
        %{bearerAuth: []}
      ],
      tags: get_api_tags()
    }

    json(conn, spec)
  end

  @doc """
  Serve the Swagger UI.
  """
  def swagger_ui(conn, _params) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>LedgerBank API Documentation</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui.css" />
      <style>
        html {
          box-sizing: border-box;
          overflow: -moz-scrollbars-vertical;
          overflow-y: scroll;
        }
        *, *:before, *:after {
          box-sizing: inherit;
        }
        body {
          margin:0;
          background: #fafafa;
        }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@4.15.5/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          const ui = SwaggerUIBundle({
            url: '/api/docs/openapi.json',
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout"
          });
        };
      </script>
    </body>
    </html>
    """

    html(conn, html)
  end

  # Private helper functions

  defp get_api_paths do
    %{
      "/health" => %{
        get: %{
          tags: ["Health"],
          summary: "Health check",
          description: "Check the health status of the API",
          responses: %{
            "200" => %{
              description: "API is healthy",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/HealthResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/health/detailed" => %{
        get: %{
          tags: ["Health"],
          summary: "Detailed health check",
          description: "Get detailed health status including database connectivity",
          responses: %{
            "200" => %{
              description: "Detailed health status",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/DetailedHealthResponse"
                  }
                }
              }
            },
            "503" => %{
              description: "Service degraded",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/DetailedHealthResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/auth/login" => %{
        post: %{
          tags: ["Authentication"],
          summary: "User login",
          description: "Authenticate a user and return access and refresh tokens",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  "$ref" => "#/components/schemas/LoginRequest"
                }
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Login successful",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/LoginResponse"
                  }
                }
              }
            },
            "401" => %{
              description: "Invalid credentials",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/auth/refresh" => %{
        post: %{
          tags: ["Authentication"],
          summary: "Refresh token",
          description: "Get a new access token using a refresh token",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  "$ref" => "#/components/schemas/RefreshRequest"
                }
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Token refreshed successfully",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/RefreshResponse"
                  }
                }
              }
            },
            "401" => %{
              description: "Invalid refresh token",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/auth/logout" => %{
        post: %{
          tags: ["Authentication"],
          summary: "User logout",
          description: "Logout a user and invalidate refresh token",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  "$ref" => "#/components/schemas/LogoutRequest"
                }
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Logout successful",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/SuccessResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/auth/me" => %{
        get: %{
          tags: ["Authentication"],
          summary: "Get current user",
          description: "Get the current authenticated user's information",
          security: [%{bearerAuth: []}],
          responses: %{
            "200" => %{
              description: "User information",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/UserResponse"
                  }
                }
              }
            },
            "401" => %{
              description: "Unauthorized",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/users" => %{
        post: %{
          tags: ["Users"],
          summary: "Create user",
          description: "Create a new user account",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  "$ref" => "#/components/schemas/CreateUserRequest"
                }
              }
            }
          },
          responses: %{
            "201" => %{
              description: "User created successfully",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/UserResponse"
                  }
                }
              }
            },
            "400" => %{
              description: "Invalid input",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        },
        get: %{
          tags: ["Users"],
          summary: "List users",
          description: "Get a list of all users (admin only)",
          security: [%{bearerAuth: []}],
          parameters: [
            %{
              name: "page",
              in: "query",
              description: "Page number",
              required: false,
              schema: %{type: "integer", minimum: 1, default: 1}
            },
            %{
              name: "page_size",
              in: "query",
              description: "Number of users per page",
              required: false,
              schema: %{type: "integer", minimum: 1, maximum: 100, default: 20}
            }
          ],
          responses: %{
            "200" => %{
              description: "List of users",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/UsersListResponse"
                  }
                }
              }
            },
            "403" => %{
              description: "Forbidden",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/users/{id}" => %{
        get: %{
          tags: ["Users"],
          summary: "Get user by ID",
          description: "Get a specific user by ID (admin only)",
          security: [%{bearerAuth: []}],
          parameters: [
            %{
              name: "id",
              in: "path",
              description: "User ID",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "200" => %{
              description: "User information",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/UserResponse"
                  }
                }
              }
            },
            "404" => %{
              description: "User not found",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        },
        put: %{
          tags: ["Users"],
          summary: "Update user",
          description: "Update a user's information (admin only)",
          security: [%{bearerAuth: []}],
          parameters: [
            %{
              name: "id",
              in: "path",
              description: "User ID",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  "$ref" => "#/components/schemas/UpdateUserRequest"
                }
              }
            }
          },
          responses: %{
            "200" => %{
              description: "User updated successfully",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/UserResponse"
                  }
                }
              }
            },
            "400" => %{
              description: "Invalid input",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/profile" => %{
        get: %{
          tags: ["Profile"],
          summary: "Get current user profile",
          description: "Get the current user's profile information",
          security: [%{bearerAuth: []}],
          responses: %{
            "200" => %{
              description: "Profile information",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/UserResponse"
                  }
                }
              }
            }
          }
        },
        put: %{
          tags: ["Profile"],
          summary: "Update profile",
          description: "Update the current user's profile",
          security: [%{bearerAuth: []}],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  "$ref" => "#/components/schemas/UpdateUserRequest"
                }
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Profile updated successfully",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/UserResponse"
                  }
                }
              }
            }
          }
        }
      },
      "/profile/password" => %{
        put: %{
          tags: ["Profile"],
          summary: "Update password",
          description: "Update the current user's password",
          security: [%{bearerAuth: []}],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  "$ref" => "#/components/schemas/UpdatePasswordRequest"
                }
              }
            }
          },
          responses: %{
            "200" => %{
              description: "Password updated successfully",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/SuccessResponse"
                  }
                }
              }
            },
            "400" => %{
              description: "Invalid input",
              content: %{
                "application/json" => %{
                  schema: %{
                    "$ref" => "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        }
      }
    }
  end

  defp get_api_schemas do
    %{
      "User" => %{
        type: "object",
        properties: %{
          id: %{type: "string", format: "uuid"},
          email: %{type: "string", format: "email"},
          full_name: %{type: "string"},
          role: %{type: "string", enum: ["user", "admin", "support"]},
          status: %{type: "string", enum: ["ACTIVE", "SUSPENDED", "DELETED"]},
          inserted_at: %{type: "string", format: "date-time"},
          updated_at: %{type: "string", format: "date-time"}
        },
        required: ["id", "email", "full_name", "role", "status"]
      },
      "HealthResponse" => %{
        type: "object",
        properties: %{
          status: %{type: "string"},
          timestamp: %{type: "string", format: "date-time"},
          version: %{type: "string"},
          uptime: %{type: "integer"}
        }
      },
      "DetailedHealthResponse" => %{
        type: "object",
        properties: %{
          status: %{type: "string"},
          timestamp: %{type: "string", format: "date-time"},
          version: %{type: "string"},
          uptime: %{type: "integer"},
          checks: %{
            type: "object",
            properties: %{
              database: %{type: "string"},
              memory: %{type: "string"},
              disk: %{type: "string"}
            }
          }
        }
      },
      "LoginRequest" => %{
        type: "object",
        properties: %{
          email: %{type: "string", format: "email"},
          password: %{type: "string", minLength: 8}
        },
        required: ["email", "password"]
      },
      "LoginResponse" => %{
        type: "object",
        properties: %{
          access_token: %{type: "string"},
          refresh_token: %{type: "string"},
          user: %{"$ref" => "#/components/schemas/User"}
        }
      },
      "RefreshRequest" => %{
        type: "object",
        properties: %{
          refresh_token: %{type: "string"}
        },
        required: ["refresh_token"]
      },
      "RefreshResponse" => %{
        type: "object",
        properties: %{
          access_token: %{type: "string"},
          refresh_token: %{type: "string"}
        }
      },
      "LogoutRequest" => %{
        type: "object",
        properties: %{
          refresh_token: %{type: "string"}
        },
        required: ["refresh_token"]
      },
      "CreateUserRequest" => %{
        type: "object",
        properties: %{
          email: %{type: "string", format: "email"},
          full_name: %{type: "string"},
          password: %{type: "string", minLength: 8},
          password_confirmation: %{type: "string", minLength: 8},
          role: %{type: "string", enum: ["user", "admin", "support"], default: "user"}
        },
        required: ["email", "full_name", "password", "password_confirmation"]
      },
      "UpdateUserRequest" => %{
        type: "object",
        properties: %{
          email: %{type: "string", format: "email"},
          full_name: %{type: "string"},
          role: %{type: "string", enum: ["user", "admin", "support"]},
          status: %{type: "string", enum: ["ACTIVE", "SUSPENDED", "DELETED"]}
        }
      },
      "UpdatePasswordRequest" => %{
        type: "object",
        properties: %{
          current_password: %{type: "string"},
          password: %{type: "string", minLength: 8},
          password_confirmation: %{type: "string", minLength: 8}
        },
        required: ["current_password", "password", "password_confirmation"]
      },
      "UserResponse" => %{
        type: "object",
        properties: %{
          data: %{"$ref" => "#/components/schemas/User"},
          success: %{type: "boolean"},
          timestamp: %{type: "string", format: "date-time"},
          correlation_id: %{type: "string"}
        }
      },
      "UsersListResponse" => %{
        type: "object",
        properties: %{
          data: %{
            type: "array",
            items: %{"$ref" => "#/components/schemas/User"}
          },
          success: %{type: "boolean"},
          timestamp: %{type: "string", format: "date-time"},
          correlation_id: %{type: "string"},
          metadata: %{
            type: "object",
            properties: %{
              page: %{type: "integer"},
              page_size: %{type: "integer"},
              total: %{type: "integer"}
            }
          }
        }
      },
      "SuccessResponse" => %{
        type: "object",
        properties: %{
          data: %{type: "object"},
          success: %{type: "boolean"},
          timestamp: %{type: "string", format: "date-time"},
          correlation_id: %{type: "string"}
        }
      },
      "ErrorResponse" => %{
        type: "object",
        properties: %{
          error: %{
            type: "object",
            properties: %{
              type: %{type: "string"},
              message: %{type: "string"},
              code: %{type: "integer"},
              timestamp: %{type: "string", format: "date-time"}
            }
          }
        }
      }
    }
  end

  defp get_api_tags do
    [
      %{name: "Health", description: "Health check endpoints"},
      %{name: "Authentication", description: "User authentication and authorization"},
      %{name: "Users", description: "User management operations"},
      %{name: "Profile", description: "User profile management"}
    ]
  end
end

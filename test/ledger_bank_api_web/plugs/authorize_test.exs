defmodule LedgerBankApiWeb.Plugs.AuthorizeTest do
  use LedgerBankApiWeb.ConnCase, async: false
  alias LedgerBankApi.UsersFixtures

  describe "init/1" do
    test "initializes with required roles" do
      opts = [roles: ["admin", "support"]]
      result = LedgerBankApiWeb.Plugs.Authorize.init(opts)

      assert result.roles == ["admin", "support"]
      assert result.error_message == "Insufficient permissions"
      assert result.allow_self == false
    end

    test "initializes with custom error message" do
      opts = [roles: ["admin"], error_message: "Admin access required"]
      result = LedgerBankApiWeb.Plugs.Authorize.init(opts)

      assert result.error_message == "Admin access required"
    end

    test "initializes with allow_self option" do
      opts = [roles: ["admin"], allow_self: true]
      result = LedgerBankApiWeb.Plugs.Authorize.init(opts)

      assert result.allow_self == true
    end

    test "defaults to empty roles and allow_self false" do
      opts = []
      result = LedgerBankApiWeb.Plugs.Authorize.init(opts)

      assert result.roles == []
      assert result.allow_self == false
    end
  end

  describe "call/2 - role-based authorization" do
    test "allows admin user when admin role required", %{conn: conn} do
      admin_user = UsersFixtures.user_fixture(%{role: "admin"})

      conn = conn
      |> assign(:current_user, admin_user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      refute conn.halted
    end

    test "allows support user when support role required", %{conn: conn} do
      support_user = UsersFixtures.user_fixture(%{role: "support"})

      conn = conn
      |> assign(:current_user, support_user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["support"],
        error_message: "Support required",
        allow_self: false
      })

      refute conn.halted
    end

    test "allows user when multiple roles accepted", %{conn: conn} do
      regular_user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, regular_user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin", "support", "user"],
        error_message: "Access required",
        allow_self: false
      })

      refute conn.halted
    end

    test "denies regular user when admin role required", %{conn: conn} do
      regular_user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, regular_user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      assert conn.halted
      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/insufficient_permissions"
      assert response["error"]["reason"] == "insufficient_permissions"
    end

    test "denies support user when admin role required", %{conn: conn} do
      support_user = UsersFixtures.user_fixture(%{role: "support"})

      conn = conn
      |> assign(:current_user, support_user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      assert conn.halted
      assert conn.status == 403
    end

    test "denies regular user when support role required", %{conn: conn} do
      regular_user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, regular_user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["support"],
        error_message: "Support required",
        allow_self: false
      })

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "call/2 - allow_self functionality" do
    test "allows user to access their own resource with allow_self", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{"id" => user.id})
      |> Map.put(:request_path, "/api/users/#{user.id}")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],  # User doesn't have admin role
        error_message: "Access required",
        allow_self: true  # But allow_self is enabled
      })

      refute conn.halted
    end

    test "denies user from accessing other user's resource even with allow_self", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})
      other_user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{"id" => other_user.id})
      |> Map.put(:request_path, "/api/users/#{other_user.id}")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      assert conn.halted
      assert conn.status == 403
    end

    test "allows access to profile endpoints with allow_self", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{})
      |> Map.put(:request_path, "/api/profile")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      refute conn.halted
    end

    test "allows access to profile sub-routes with allow_self", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{})
      |> Map.put(:request_path, "/api/profile/password")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      refute conn.halted
    end

    test "denies access to non-profile routes without matching role", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{})
      |> Map.put(:request_path, "/api/admin/something")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "call/2 - missing current_user" do
    test "denies request when current_user is not assigned", %{conn: conn} do
      conn = LedgerBankApiWeb.Plugs.Authorize.call(conn, %{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      assert conn.halted
      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/unauthorized_access"
      assert response["error"]["reason"] == "unauthorized_access"
    end

    test "denies request when current_user is nil", %{conn: conn} do
      conn = conn
      |> assign(:current_user, nil)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "call/2 - error response format" do
    test "returns properly formatted error with custom message", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Administrator access required",
        allow_self: false
      })

      response = json_response(conn, 403)

      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/insufficient_permissions"
      assert response["error"]["reason"] == "insufficient_permissions"
      assert response["error"]["code"] == 403
    end

    test "includes user context in error details", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:request_path, "/api/admin/users")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      response = json_response(conn, 403)

      # Verify error structure
      assert response["error"]["reason"] == "insufficient_permissions"
      assert response["error"]["category"] == "authorization"
    end
  end

  describe "call/2 - edge cases with path params" do
    test "handles missing id parameter gracefully", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{})  # No id param
      |> Map.put(:request_path, "/api/users")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      assert conn.halted  # Should fail - no matching role and no self-access
      assert conn.status == 403
    end

    test "handles invalid UUID in id parameter", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{"id" => "invalid-uuid"})
      |> Map.put(:request_path, "/api/users/invalid-uuid")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      assert conn.halted
      assert conn.status == 403
    end

    test "handles nil id parameter", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{"id" => nil})
      |> Map.put(:request_path, "/api/users/")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      assert conn.halted
      assert conn.status == 403
    end
  end

  describe "call/2 - multiple role combinations" do
    test "admin can access with admin-only requirement", %{conn: conn} do
      admin = UsersFixtures.user_fixture(%{role: "admin"})

      conn = conn
      |> assign(:current_user, admin)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      refute conn.halted
    end

    test "admin can access with admin-or-support requirement", %{conn: conn} do
      admin = UsersFixtures.user_fixture(%{role: "admin"})

      conn = conn
      |> assign(:current_user, admin)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin", "support"],
        error_message: "Admin or Support required",
        allow_self: false
      })

      refute conn.halted
    end

    test "support can access with admin-or-support requirement", %{conn: conn} do
      support = UsersFixtures.user_fixture(%{role: "support"})

      conn = conn
      |> assign(:current_user, support)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin", "support"],
        error_message: "Admin or Support required",
        allow_self: false
      })

      refute conn.halted
    end

    test "user can access with any-role requirement", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin", "support", "user"],
        error_message: "Authentication required",
        allow_self: false
      })

      refute conn.halted
    end
  end

  describe "call/2 - integration with allow_self" do
    test "user can access own profile with allow_self enabled", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:request_path, "/api/profile")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      refute conn.halted
    end

    test "admin can bypass allow_self check with admin role", %{conn: conn} do
      admin = UsersFixtures.user_fixture(%{role: "admin"})
      other_user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, admin)
      |> Map.put(:path_params, %{"id" => other_user.id})
      |> Map.put(:request_path, "/api/users/#{other_user.id}")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Access required",
        allow_self: true
      })

      refute conn.halted  # Admin has the role
    end

    test "user accessing own resource with matching role passes", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{"id" => user.id})
      |> Map.put(:request_path, "/api/users/#{user.id}")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["user"],
        error_message: "Access required",
        allow_self: false
      })

      refute conn.halted  # Has the role
    end
  end

  describe "call/2 - error scenarios" do
    test "returns 403 with insufficient permissions", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin access required",
        allow_self: false
      })

      response = json_response(conn, 403)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/insufficient_permissions"
      assert response["error"]["reason"] == "insufficient_permissions"
    end

    test "returns 403 when user not authenticated", %{conn: conn} do
      conn = LedgerBankApiWeb.Plugs.Authorize.call(conn, %{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      response = json_response(conn, 403)
      assert response["error"]["type"] == "https://api.ledgerbank.com/problems/unauthorized_access"
      assert response["error"]["reason"] == "unauthorized_access"
    end

    test "includes context in error response", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:request_path, "/api/admin/stats")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      response = json_response(conn, 403)
      assert response["error"]["reason"] == "insufficient_permissions"
      assert response["error"]["category"] == "authorization"
    end
  end

  describe "call/2 - empty roles list" do
    test "denies all access when roles list is empty", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "admin"})

      conn = conn
      |> assign(:current_user, user)
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: [],
        error_message: "No access",
        allow_self: false
      })

      assert conn.halted
      assert conn.status == 403
    end

    test "allows access with empty roles if allow_self and accessing own resource", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{"id" => user.id})
      |> Map.put(:request_path, "/api/users/#{user.id}")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: [],
        error_message: "Access required",
        allow_self: true
      })

      refute conn.halted
    end
  end

  describe "call/2 - real-world authorization scenarios" do
    test "admin can list all users", %{conn: conn} do
      admin = UsersFixtures.user_fixture(%{role: "admin"})

      conn = conn
      |> assign(:current_user, admin)
      |> Map.put(:request_path, "/api/users")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],
        error_message: "Admin required",
        allow_self: false
      })

      refute conn.halted
    end

    test "support cannot delete users", %{conn: conn} do
      support = UsersFixtures.user_fixture(%{role: "support"})
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, support)
      |> Map.put(:path_params, %{"id" => user.id})
      |> Map.put(:request_path, "/api/users/#{user.id}")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin"],  # Only admin can delete
        error_message: "Admin required",
        allow_self: false
      })

      assert conn.halted
      assert conn.status == 403
    end

    test "user can update their own profile", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{role: "user"})

      conn = conn
      |> assign(:current_user, user)
      |> Map.put(:request_path, "/api/profile")
      |> LedgerBankApiWeb.Plugs.Authorize.call(%{
        roles: ["admin", "user", "support"],
        error_message: "Access required",
        allow_self: true
      })

      refute conn.halted
    end
  end
end

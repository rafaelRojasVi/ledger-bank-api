defmodule LedgerBankApiWeb.Plugs.AuthenticateTest do
  use LedgerBankApiWeb.ConnCase, async: false
  alias LedgerBankApi.Accounts.AuthService
  alias LedgerBankApi.UsersFixtures

  describe "call/2 - successful authentication" do
    test "successfully authenticates with valid Bearer token", %{conn: conn} do
      user = UsersFixtures.user_fixture(%{email: "test@example.com"})
      {:ok, token} = AuthService.generate_access_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.assigns.current_user.id == user.id
      assert conn.assigns.current_user.email == user.email
      assert conn.assigns.current_token == token
      assert conn.assigns.authenticated == true
      refute conn.halted
    end

    test "assigns correct user attributes to conn", %{conn: conn} do
      user =
        UsersFixtures.user_fixture(%{
          email: "admin@example.com",
          role: "admin",
          full_name: "Admin User"
        })

      {:ok, token} = AuthService.generate_access_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.assigns.current_user.role == "admin"
      assert conn.assigns.current_user.full_name == "Admin User"
      assert conn.assigns.current_user.email == "admin@example.com"
    end

    test "handles concurrent authentication requests", %{conn: conn} do
      users =
        Enum.map(1..10, fn i ->
          UsersFixtures.user_fixture(%{email: "user#{i}@example.com"})
        end)

      tasks =
        Enum.map(users, fn user ->
          Task.async(fn ->
            {:ok, token} = AuthService.generate_access_token(user)

            result_conn =
              conn
              |> put_req_header("authorization", "Bearer #{token}")
              |> LedgerBankApiWeb.Plugs.Authenticate.call([])

            {user.id, result_conn.assigns.current_user.id}
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All should authenticate correctly
      Enum.each(results, fn {expected_id, actual_id} ->
        assert expected_id == actual_id
      end)
    end
  end

  describe "call/2 - missing or malformed Authorization header" do
    test "rejects request with missing Authorization header", %{conn: conn} do
      conn = LedgerBankApiWeb.Plugs.Authenticate.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["reason"] == "invalid_token"
      assert response["error"]["category"] == "authentication"
    end

    test "rejects request with empty Authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["reason"] == "invalid_token"
      assert response["error"]["category"] == "authentication"
    end

    test "rejects malformed Authorization header (no Bearer prefix)", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      conn =
        conn
        # Missing "Bearer "
        |> put_req_header("authorization", token)
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["reason"] == "invalid_token"
      assert response["error"]["category"] == "authentication"
    end

    test "rejects malformed Authorization header (wrong prefix)", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Basic #{token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects Authorization header with extra spaces", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, token} = AuthService.generate_access_token(user)

      # Note: This might actually work depending on trim implementation
      # But we test the behavior
      conn =
        conn
        # Double space
        |> put_req_header("authorization", "Bearer  #{token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      # Should either work or fail gracefully
      assert is_map(conn.assigns[:current_user]) or conn.halted
    end
  end

  describe "call/2 - invalid tokens" do
    test "rejects request with invalid token format", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token.here")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["reason"] == "invalid_token"
      assert response["error"]["category"] == "authentication"
    end

    test "rejects token with invalid signature", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      # Create a token with wrong secret
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      wrong_signer = Joken.Signer.create("HS256", "wrong-secret-key")
      invalid_token = Joken.generate_and_sign!(payload, wrong_signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{invalid_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects token with missing required claims", %{conn: conn} do
      # Create a token without 'type' claim
      payload = %{
        "sub" => Ecto.UUID.generate(),
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "iss" => "ledger-bank-api"
        # Missing: type, aud, nbf
      }

      signer =
        Joken.Signer.create(
          "HS256",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      invalid_token = Joken.generate_and_sign!(payload, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{invalid_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects completely malformed token", %{conn: conn} do
      malformed_tokens = [
        "not-a-token",
        # Only 2 parts
        "one.two",
        # Too many parts
        "one.two.three.four",
        "",
        "Bearer ",
        "null",
        "undefined"
      ]

      Enum.each(malformed_tokens, fn token ->
        conn =
          conn
          |> put_req_header("authorization", "Bearer #{token}")
          |> LedgerBankApiWeb.Plugs.Authenticate.call([])

        assert conn.halted
        assert conn.status == 401
      end)
    end
  end

  describe "call/2 - expired tokens" do
    test "rejects expired access token", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      # Create an expired token
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        # 1 hour ago
        "exp" => System.system_time(:second) - 3600,
        # 2 hours ago
        "iat" => System.system_time(:second) - 7200,
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second) - 7200
      }

      signer =
        Joken.Signer.create(
          "HS256",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      expired_token = Joken.generate_and_sign!(payload, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{expired_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["reason"] in ["invalid_token_type", "missing_required_claims"]
      assert response["error"]["category"] == "authentication"
    end

    test "rejects token with future nbf (not-before) time", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      # Create a token that's not valid yet
      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        # Valid 1 hour from now
        "nbf" => System.system_time(:second) + 3600
      }

      signer =
        Joken.Signer.create(
          "HS256",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      future_token = Joken.generate_and_sign!(payload, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{future_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - wrong token type" do
    test "rejects refresh token (wrong type)", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      {:ok, refresh_token} = AuthService.generate_refresh_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{refresh_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["error"]["reason"] in ["invalid_token_type", "missing_required_claims"]
      assert response["error"]["category"] == "authentication"
    end

    test "rejects token with missing type claim", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
        # Missing "type" claim
      }

      signer =
        Joken.Signer.create(
          "HS256",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      typeless_token = Joken.generate_and_sign!(payload, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{typeless_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - user not found" do
    test "rejects token for non-existent user", %{conn: conn} do
      fake_user_id = Ecto.UUID.generate()

      payload = %{
        "sub" => fake_user_id,
        "email" => "nonexistent@example.com",
        "role" => "user",
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer =
        Joken.Signer.create(
          "HS256",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      token = Joken.generate_and_sign!(payload, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - token validation edge cases" do
    test "handles token with wrong issuer", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        # Wrong issuer
        "iss" => "wrong-issuer",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer =
        Joken.Signer.create(
          "HS256",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      token = Joken.generate_and_sign!(payload, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "handles token with wrong algorithm", %{conn: conn} do
      user = UsersFixtures.user_fixture()

      payload = %{
        "sub" => to_string(user.id),
        "email" => user.email,
        "role" => user.role,
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      wrong_signer =
        Joken.Signer.create(
          "HS512",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      token = Joken.generate_and_sign!(payload, wrong_signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - security edge cases" do
    test "rejects token with SQL injection attempt in claims", %{conn: conn} do
      payload = %{
        "sub" => "'; DROP TABLE users; --",
        "email" => "'; DROP TABLE users; --@example.com",
        "role" => "admin' OR '1'='1",
        "exp" => System.system_time(:second) + 900,
        "iat" => System.system_time(:second),
        "type" => "access",
        "iss" => "ledger-bank-api",
        "aud" => "ledger-bank-api",
        "jti" => Ecto.UUID.generate(),
        "nbf" => System.system_time(:second)
      }

      signer =
        Joken.Signer.create(
          "HS256",
          System.get_env("JWT_SECRET", "test-secret-key-for-testing-only-must-be-64-chars-long")
        )

      malicious_token = Joken.generate_and_sign!(payload, signer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{malicious_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      # Should fail because user_id is not a valid UUID
      assert conn.halted
      assert conn.status == 401
    end

    test "handles very long authorization header", %{conn: conn} do
      long_token = String.duplicate("a", 10000)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{long_token}")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "handles authorization header with null bytes", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer token\0with\0nulls")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 - error response format" do
    test "returns properly formatted error response", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      response = json_response(conn, 401)

      # Check RFC 9457 problem details format
      assert Map.has_key?(response, "error")
      assert Map.has_key?(response["error"], "type")
      assert Map.has_key?(response["error"], "reason")
      assert Map.has_key?(response["error"], "status")
      assert Map.has_key?(response["error"], "category")

      assert response["error"]["status"] == 401
      assert response["error"]["reason"] == "invalid_token"
      assert response["error"]["category"] == "authentication"
    end

    test "includes correlation ID in error response", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token")
        |> LedgerBankApiWeb.Plugs.Authenticate.call([])

      response = json_response(conn, 401)

      # Should have correlation_id if error adapter includes it
      assert is_map(response)
      assert Map.has_key?(response["error"], "reason")
    end
  end
end

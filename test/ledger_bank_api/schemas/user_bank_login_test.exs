defmodule LedgerBankApi.Banking.Schemas.UserBankLoginTest do
  use LedgerBankApi.DataCase, async: true
  alias LedgerBankApi.Banking.Schemas.UserBankLogin

  describe "changeset/2" do
    test "valid changeset with OAuth2 tokens" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        bank_branch_id: Ecto.UUID.generate(),
        username: "testuser",
        access_token: "access_token_123",
        refresh_token: "refresh_token_123",
        token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        scope: "read write"
      }

      changeset = UserBankLogin.changeset(%UserBankLogin{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with minimal required fields" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        bank_branch_id: Ecto.UUID.generate(),
        username: "testuser"
      }

      changeset = UserBankLogin.changeset(%UserBankLogin{}, attrs)

      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      attrs = %{
        username: "testuser"
      }

      changeset = UserBankLogin.changeset(%UserBankLogin{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset).user_id
      assert errors_on(changeset).bank_branch_id
    end
  end

  describe "token validation functions" do
    test "token_valid? returns true for valid token" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      login = %UserBankLogin{
        access_token: "valid_token",
        token_expires_at: future_time
      }

      assert UserBankLogin.token_valid?(login)
    end

    test "token_valid? returns false for expired token" do
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)
      login = %UserBankLogin{
        access_token: "expired_token",
        token_expires_at: past_time
      }

      refute UserBankLogin.token_valid?(login)
    end

    test "token_valid? returns false for nil token" do
      login = %UserBankLogin{
        access_token: nil,
        token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      refute UserBankLogin.token_valid?(login)
    end
  end

  describe "is_active?/1" do
    test "returns true for active login" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      login = %UserBankLogin{
        status: "ACTIVE",
        access_token: "valid_token",
        token_expires_at: future_time
      }
      assert UserBankLogin.is_active?(login)
    end

    test "returns false for inactive login" do
      login = %UserBankLogin{status: "INACTIVE"}
      refute UserBankLogin.is_active?(login)
    end

    test "returns false for active login with expired token" do
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)
      login = %UserBankLogin{
        status: "ACTIVE",
        access_token: "expired_token",
        token_expires_at: past_time
      }
      refute UserBankLogin.is_active?(login)
    end
  end

  describe "needs_sync?/1" do
    test "returns true when last_sync_at is nil" do
      login = %UserBankLogin{last_sync_at: nil}
      assert UserBankLogin.needs_sync?(login)
    end

    test "returns true when sync frequency has passed" do
      old_time = DateTime.add(DateTime.utc_now(), -4000, :second)
      login = %UserBankLogin{
        last_sync_at: old_time,
        sync_frequency: 3600
      }
      assert UserBankLogin.needs_sync?(login)
    end

    test "returns false when sync frequency has not passed" do
      recent_time = DateTime.add(DateTime.utc_now(), -1800, :second)
      login = %UserBankLogin{
        last_sync_at: recent_time,
        sync_frequency: 3600
      }
      refute UserBankLogin.needs_sync?(login)
    end
  end

  describe "needs_token_refresh?/1" do
    test "returns true when token_expires_at is nil" do
      login = %UserBankLogin{token_expires_at: nil}
      assert UserBankLogin.needs_token_refresh?(login)
    end

    test "returns true when token expires within 5 minutes" do
      near_expiry = DateTime.add(DateTime.utc_now(), 240, :second)  # 4 minutes
      login = %UserBankLogin{token_expires_at: near_expiry}
      assert UserBankLogin.needs_token_refresh?(login)
    end

    test "returns false when token expires in more than 5 minutes" do
      far_expiry = DateTime.add(DateTime.utc_now(), 600, :second)  # 10 minutes
      login = %UserBankLogin{token_expires_at: far_expiry}
      refute UserBankLogin.needs_token_refresh?(login)
    end
  end
end

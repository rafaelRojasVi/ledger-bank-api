defmodule LedgerBankApi.Users.RefreshTokenTest do
  use ExUnit.Case, async: true
  alias LedgerBankApi.Users.RefreshToken

  test "revoked?/1 returns false if not revoked" do
    token = %RefreshToken{revoked_at: nil}
    refute RefreshToken.revoked?(token)
  end

  test "revoked?/1 returns true if revoked" do
    token = %RefreshToken{revoked_at: DateTime.utc_now()}
    assert RefreshToken.revoked?(token)
  end

  test "expired?/1 returns true if expired" do
    token = %RefreshToken{expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)}
    assert RefreshToken.expired?(token)
  end

  test "expired?/1 returns false if not expired" do
    token = %RefreshToken{expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)}
    refute RefreshToken.expired?(token)
  end
end

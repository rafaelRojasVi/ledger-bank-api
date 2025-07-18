defmodule LedgerBankApi.Banking.Integrations.MonzoClient do
  @behaviour LedgerBankApi.Banking.BankApiClient

  @api_url "https://api.monzo.com"

  def fetch_accounts(%{access_token: token}) do
    headers = [{"Authorization", "Bearer #{token}"}]
    url = "#{@api_url}/accounts"
    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"accounts" => accounts}}} -> {:ok, accounts}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  def fetch_transactions(account_id, %{access_token: token, since: since}) do
    headers = [{"Authorization", "Bearer #{token}"}]
    url = "#{@api_url}/transactions?account_id=#{account_id}&since=#{since}"
    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"transactions" => txns}}} -> {:ok, txns}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  def fetch_balance(account_id, %{access_token: token}) do
    headers = [{"Authorization", "Bearer #{token}"}]
    url = "#{@api_url}/balance?account_id=#{account_id}"
    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: balance}} -> {:ok, balance}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end
end

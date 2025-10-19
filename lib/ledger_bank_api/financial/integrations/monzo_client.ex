defmodule LedgerBankApi.Financial.Integrations.MonzoClient do
  @moduledoc """
  Monzo bank integration client.

  Implements the BankApiClient behaviour for Monzo API integration.
  """

  @behaviour LedgerBankApi.Financial.Integrations.BankApiClient

  @api_url Application.compile_env(:ledger_bank_api, :monzo_api_url, "https://api.monzo.com")

  @impl true
  def fetch_accounts(%{access_token: token}) do
    LedgerBankApi.Core.CircuitBreaker.call_with_fallback(:bank_api,
      fn ->
        headers = [{"Authorization", "Bearer #{token}"}]
        url = "#{@api_url}/accounts"
        case Req.get(url, headers: headers) do
          {:ok, %{status: 200, body: %{"accounts" => accounts}}} -> {:ok, accounts}
          {:ok, %{status: status, body: body}} -> {:error, {status, body}}
          error -> error
        end
      end,
      fn -> {:ok, []} end,
      timeout: 30_000
    )
  end

  @impl true
  def fetch_transactions(account_id, %{access_token: token, since: since}) do
    headers = [{"Authorization", "Bearer #{token}"}]
    url = "#{@api_url}/transactions?account_id=#{account_id}&since=#{since}"
    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"transactions" => txns}}} -> {:ok, txns}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  @impl true
  def fetch_balance(account_id, %{access_token: token}) do
    headers = [{"Authorization", "Bearer #{token}"}]
    url = "#{@api_url}/balance?account_id=#{account_id}"
    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: balance}} -> {:ok, balance}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  @impl true
  def fetch_transactions(%{access_token: token, account_id: account_id, since: since}) do
    fetch_transactions(account_id, %{access_token: token, since: since})
  end

  @impl true
  def create_payment(%{access_token: token, account_id: account_id, amount: amount, description: description}) do
    headers = [{"Authorization", "Bearer #{token}"}, {"Content-Type", "application/json"}]
    url = "#{@api_url}/feed"
    body = %{
      account_id: account_id,
      type: "basic",
      url: "https://ledger-bank-api.com/payment/#{System.unique_integer([:positive])}",
      params: %{
        title: "Payment: #{description}",
        body: "Amount: #{amount}",
        image_url: "https://ledger-bank-api.com/icon.png"
      }
    }
    case Req.post(url, json: body, headers: headers) do
      {:ok, %{status: 200, body: response}} -> {:ok, response}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end

  @impl true
  def get_payment_status(%{access_token: token, payment_id: payment_id}) do
    headers = [{"Authorization", "Bearer #{token}"}]
    url = "#{@api_url}/transactions/#{payment_id}"
    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"transaction" => transaction}}} ->
        # Map Monzo transaction status to our payment status
        status = case transaction["decline_reason"] do
          nil -> "completed"
          _ -> "failed"
        end
        {:ok, %{id: payment_id, status: status, transaction: transaction}}
      {:ok, %{status: 404}} ->
        {:error, :payment_not_found}
      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}
      error -> error
    end
  end

  @impl true
  def refresh_token(%{refresh_token: refresh_token}) do
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    body = %{
      grant_type: "refresh_token",
      client_id: System.get_env("MONZO_CLIENT_ID"),
      client_secret: System.get_env("MONZO_CLIENT_SECRET"),
      refresh_token: refresh_token
    }
    url = "#{@api_url}/oauth2/token"
    case Req.post(url, form: body, headers: headers) do
      {:ok, %{status: 200, body: %{"access_token" => access_token, "refresh_token" => new_refresh_token}}} ->
        {:ok, %{access_token: access_token, refresh_token: new_refresh_token}}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      error -> error
    end
  end
end

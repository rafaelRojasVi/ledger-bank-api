Mox.defmock(LedgerBankApi.External.BankClientMock,
            for: LedgerBankApi.External.BankClient)

Application.put_env(:ledger_bank_api, :bank_client,
                    LedgerBankApi.External.BankClientMock)

ExUnit.start()

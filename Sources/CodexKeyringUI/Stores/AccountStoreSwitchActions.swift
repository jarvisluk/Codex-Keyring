import CodexKeyringDomain

extension AccountStore {
    public func switchTo(_ account: CodexAccount, restartCodexApp: Bool) {
        guard canSwitch(to: account) else { return }
        logService?.info("switching to alias=\(account.alias) (restartCodexApp=\(restartCodexApp))")
        run {
            let result = try await self.useCases.switchAccount(
                accountID: account.id,
                restartCodexApp: restartCodexApp
            )
            self.apply(result.state)
            self.statusMessage = AccountStoreStatusMessages.switchAccount(
                result: result,
                restartWasRequested: restartCodexApp
            )
            self.logService?.info("switch complete alias=\(result.switchedAlias) wasAlreadyActive=\(result.wasAlreadyActive) restartOutcome=\(String(describing: result.restartOutcome))")
        }
    }
}

import CodexKeyringDomain

extension AccountStore {
    public func refresh() {
        guard canRefreshAccounts else { return }
        isRefreshInProgress = true
        statusMessage = "Refreshing account state..."
        run {
            defer { self.isRefreshInProgress = false }
            self.logService?.debug("refreshing account state")
            let state = try await self.useCases.refreshState()
            self.apply(state)
            if self.lastError == nil && !self.isQuotaRefreshInProgress {
                self.statusMessage = "Refreshed accounts."
            }
            self.logService?.info("refreshed; accounts=\(state.accounts.count), activeID=\(state.activeAccountID?.uuidString ?? "<none>")")
        }
    }
}

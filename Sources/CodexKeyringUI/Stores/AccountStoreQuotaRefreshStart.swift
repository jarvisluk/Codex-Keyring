import CodexKeyringDomain

struct AccountStoreQuotaRefreshStart {
    let preserveExistingError: Bool
}

extension AccountStore {
    func beginQuotaRefresh(allowDuringAccountWork: Bool) -> AccountStoreQuotaRefreshStart? {
        guard settings.allowNetworkQuotaAPIs else {
            lastError = nil
            quotaStates = [:]
            statusMessage = "Network quota API calls are disabled."
            return nil
        }

        guard !accounts.isEmpty else {
            lastError = nil
            quotaStates = [:]
            statusMessage = "No saved accounts to refresh quotas for."
            return nil
        }

        if allowDuringAccountWork {
            guard !isQuotaRefreshInProgress else { return nil }
        } else {
            guard canRefreshQuotas else { return nil }
        }

        let start = AccountStoreQuotaRefreshStart(
            preserveExistingError: allowDuringAccountWork && lastError != nil
        )
        isQuotaRefreshInProgress = true
        if !start.preserveExistingError {
            statusMessage = "Refreshing account quotas..."
        }
        quotaStates = AccountQuotaStateReducer.markingChatGPTAccountsLoading(
            quotaStates,
            accounts: accounts
        )
        return start
    }
}

import Foundation
import CodexKeyringDomain

extension AccountStore {
    public func refreshQuotasNow() {
        refreshQuotas(allowDuringAccountWork: false)
    }

    func refreshQuotas(allowDuringAccountWork: Bool) {
        guard let start = beginQuotaRefresh(allowDuringAccountWork: allowDuringAccountWork) else { return }

        run(
            clearErrorOnStart: !start.preserveExistingError,
            reportErrorOnFailure: !start.preserveExistingError
        ) {
            defer { self.isQuotaRefreshInProgress = false }
            self.logService?.debug("refreshing account quotas")
            let result = try await self.useCases.refreshAccountQuotas()
            self.accounts = result.accounts
            self.quotaStates = result.states
            if !start.preserveExistingError && self.lastError == nil {
                self.statusMessage = AccountStoreStatusMessages.quotaRefresh(result: result)
            }
            let successfulCount = result.states.values.filter { $0.phase == .available }.count
            self.logService?.info("quota refresh complete; accounts=\(result.states.count), successful=\(successfulCount)")
        } onFailure: { error in
            self.isQuotaRefreshInProgress = false
            self.markLoadingQuotaStatesFailed(error)
        }
    }

    func markLoadingQuotaStatesFailed(_ error: Error) {
        quotaStates = AccountQuotaStateReducer.markingLoadingStatesFailed(
            quotaStates,
            message: error.localizedDescription,
            updatedAt: Date()
        )
    }

    func configureQuotaRefresh(current: AppSettings) {
        if !current.allowNetworkQuotaAPIs {
            quotaStates = [:]
        }

        let shouldRefreshImmediately = quotaRefreshScheduler.configure(
            settings: current,
            accountIDs: Set(accounts.map(\.id))
        ) { [weak self] in
            self?.refreshQuotasNow()
        }
        if shouldRefreshImmediately {
            refreshQuotas(allowDuringAccountWork: true)
        }
    }
}

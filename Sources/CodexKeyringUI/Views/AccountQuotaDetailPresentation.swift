import CodexKeyringDomain

struct AccountQuotaDetailPresentation: Equatable {
    enum Content: Equatable {
        case networkDisabled(String)
        case quotaState(AccountQuotaState)
        case notRefreshed(String)
    }

    let canRefreshQuotas: Bool
    let content: Content

    init(
        allowNetworkQuotaAPIs: Bool,
        quotaState: AccountQuotaState?,
        canRefreshQuotas: Bool
    ) {
        self.canRefreshQuotas = canRefreshQuotas
        if !allowNetworkQuotaAPIs {
            content = .networkDisabled("Network quota API calls are disabled in Settings.")
        } else if let quotaState {
            content = .quotaState(quotaState)
        } else {
            content = .notRefreshed("Quota has not been refreshed yet.")
        }
    }
}

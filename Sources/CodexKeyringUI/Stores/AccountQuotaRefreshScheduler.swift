import Foundation
import CodexKeyringDomain

final class AccountQuotaRefreshScheduler {
    private var refreshTask: Task<Void, Never>?
    private var configuration: AccountQuotaRefreshConfiguration?

    deinit {
        cancel()
    }

    func cancel() {
        refreshTask?.cancel()
        refreshTask = nil
        configuration = nil
    }

    func configure(
        settings: AppSettings,
        accountIDs: Set<UUID>,
        refresh: @escaping @MainActor @Sendable () -> Void
    ) -> Bool {
        let wasEnabled = configuration?.enabled == true
        let previousAccountIDs = configuration?.accountIDs ?? []
        let nextConfiguration = AccountQuotaRefreshConfiguration(
            enabled: settings.allowNetworkQuotaAPIs && !accountIDs.isEmpty,
            intervalMinutes: settings.quotaRefreshIntervalMinutes,
            accountIDs: accountIDs
        )
        guard configuration != nextConfiguration else { return false }

        configuration = nextConfiguration
        refreshTask?.cancel()
        refreshTask = nil

        guard nextConfiguration.enabled else { return false }

        refreshTask = Task { @MainActor [nextConfiguration, refresh] in
            while !Task.isCancelled {
                let seconds = UInt64(max(1, nextConfiguration.intervalMinutes) * 60)
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                if Task.isCancelled { break }
                refresh()
            }
        }

        let addedAccountIDs = accountIDs.subtracting(previousAccountIDs)
        return !wasEnabled || !addedAccountIDs.isEmpty
    }
}

private struct AccountQuotaRefreshConfiguration: Equatable {
    var enabled: Bool
    var intervalMinutes: Int
    var accountIDs: Set<UUID>
}

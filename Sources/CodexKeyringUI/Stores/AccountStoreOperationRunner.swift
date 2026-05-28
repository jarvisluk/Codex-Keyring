import Foundation
import CodexKeyringDomain

extension AccountStore {
    func run(
        clearErrorOnStart: Bool = true,
        reportErrorOnFailure: Bool = true,
        _ operation: @escaping @MainActor @Sendable () async throws -> Void,
        onFailure: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        if clearErrorOnStart {
            lastError = nil
        }
        beginQueuedOperation()
        operationQueue.enqueue {
            defer { self.finishQueuedOperation() }
            try await operation()
        } onFailure: { [weak self] error in
            onFailure?(error)
            if reportErrorOnFailure {
                self?.setError(error)
            } else {
                self?.logService?.error("background operation failed: \(error.localizedDescription)")
            }
        }
    }

    func beginQueuedOperation() {
        queuedOperationCount += 1
        isOperationInProgress = true
    }

    func finishQueuedOperation() {
        queuedOperationCount = max(0, queuedOperationCount - 1)
        isOperationInProgress = queuedOperationCount > 0
    }

    func apply(_ state: AccountState) {
        accounts = state.accounts
        activeAccountID = state.activeAccountID
        currentAuthMetadata = state.currentAuthMetadata
        pruneQuotaStates()
        apply(state.settings)
    }

    func apply(_ settings: AppSettings) {
        var resolved = settings
        resolved.launchAtLogin = launchAtLoginController.isEnabled
        self.settings = resolved
        configureQuotaRefresh(current: resolved)
    }

    func setError(_ error: Error) {
        lastError = error.localizedDescription
        statusMessage = error.localizedDescription
        logService?.error("operation failed: \(error.localizedDescription)")
    }

    func pruneQuotaStates() {
        quotaStates = AccountQuotaStateReducer.pruning(quotaStates, keepingAccounts: accounts)
    }
}

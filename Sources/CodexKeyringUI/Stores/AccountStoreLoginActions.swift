import Foundation
import CodexKeyringDomain

extension AccountStore {
    public func loginNewCodexAccount() {
        guard canLoginNewAccount else { return }
        isLoginInProgress = true
        loginCancellationRequested = false
        lastError = nil
        statusMessage = "Opening Codex login..."
        logService?.info("starting Codex ChatGPT OAuth flow")

        loginOperationTask = run(reportErrorOnFailure: false) {
            defer { self.isLoginInProgress = false }
            let result = try await self.useCases.loginNewAccount { url in
                try await self.openAuthURL(url)
                await MainActor.run {
                    self.statusMessage = "Complete the Codex login in your browser. This will time out after 5 minutes."
                }
            }
            self.apply(result.state)
            self.statusMessage = AccountStoreStatusMessages.loginSuccess(
                savedAlias: result.savedAlias,
                cleanupWarningReason: result.cleanupWarningReason
            )
            if let cleanupWarningReason = result.cleanupWarningReason {
                self.logService?.warning("login staging cleanup warning: \(cleanupWarningReason)")
            }
            self.logService?.info("saved new login alias=\(result.savedAlias) without switching active auth")
            self.loginOperationTask = nil
            self.loginCancellationRequested = false
        } onFailure: { error in
            self.isLoginInProgress = false
            self.loginOperationTask = nil
            if self.loginCancellationRequested && self.isLoginCancellation(error) {
                self.loginCancellationRequested = false
                self.lastError = nil
                self.statusMessage = "Codex login cancelled."
                self.logService?.info("Codex ChatGPT OAuth flow cancelled")
                return
            }
            self.loginCancellationRequested = false
            self.setError(error)
        }
    }

    public func cancelLoginNewCodexAccount() {
        guard isLoginInProgress else { return }
        loginCancellationRequested = true
        lastError = nil
        statusMessage = "Cancelling Codex login..."
        logService?.info("cancelling Codex ChatGPT OAuth flow")
        loginOperationTask?.cancel()
    }

    private func isLoginCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        guard case let CodexKeyringError.codexLoginFailed(reason) = error else {
            return false
        }
        return reason.localizedCaseInsensitiveContains("cancel")
    }
}

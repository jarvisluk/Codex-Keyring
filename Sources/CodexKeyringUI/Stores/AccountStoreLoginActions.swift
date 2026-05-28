import Foundation
import CodexKeyringDomain

extension AccountStore {
    public func loginNewCodexAccount() {
        guard canLoginNewAccount else { return }
        isLoginInProgress = true
        lastError = nil
        statusMessage = "Opening Codex login..."
        logService?.info("starting Codex ChatGPT OAuth flow")

        run {
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
        } onFailure: { _ in
            self.isLoginInProgress = false
        }
    }
}

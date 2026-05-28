import Foundation

/// Run the Codex browser login flow, save the newly written auth as a snapshot,
/// then restore the user's previous live auth so the active account is unchanged.
public struct LoginNewAccountUseCase: Sendable {
    let repository: any AccountRepository
    let installer: any CodexAuthInstalling
    let authReader: any AuthFileReading
    let loginService: any CodexLoginServicing
    let preferencesPort: any CodexAgentPreferencesPorting
    let clock: any Clock
    let aliasPolicy: AliasPolicy

    public init(
        repository: any AccountRepository,
        installer: any CodexAuthInstalling,
        authReader: any AuthFileReading,
        loginService: any CodexLoginServicing,
        preferencesPort: any CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort(),
        clock: any Clock = SystemClock(),
        aliasPolicy: AliasPolicy = AliasPolicy()
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.loginService = loginService
        self.preferencesPort = preferencesPort
        self.clock = clock
        self.aliasPolicy = aliasPolicy
    }

    public func callAsFunction(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws -> LoginNewAccountResult {
        let restoreURL = try await installer.stageLiveAuthIfPresent(prefix: "pre-login")
        var newLoginURL: URL?
        var didRestorePreviousLiveAuth = false
        let result: LoginNewAccountResult

        do {
            try await loginService.loginWithChatGPT(openAuthURL: openAuthURL)
            let stagedLoginURL = try await installer.stageRequiredLiveAuth(prefix: "new-login")
            newLoginURL = stagedLoginURL
            try await installer.restoreLiveAuth(from: restoreURL)
            didRestorePreviousLiveAuth = true

            result = try await saveInactiveNewAccount(from: stagedLoginURL)
        } catch {
            let restoredPreviousLiveAuth: Bool
            if didRestorePreviousLiveAuth {
                restoredPreviousLiveAuth = true
            } else {
                restoredPreviousLiveAuth = await tryRestorePreviousLiveAuth(from: restoreURL)
            }
            if restoredPreviousLiveAuth {
                _ = await cleanupStagedAuthFiles([restoreURL])
            }
            _ = await cleanupStagedAuthFiles([newLoginURL])
            if !restoredPreviousLiveAuth {
                throw CodexKeyringError.previousAuthRestoreFailed(
                    reason: error.localizedDescription,
                    recoveryPath: restoreURL?.path
                )
            }
            throw error
        }

        let cleanupWarningReason = await cleanupStagedAuthFiles([restoreURL, newLoginURL])
        return LoginNewAccountResult(
            state: result.state,
            savedAlias: result.savedAlias,
            cleanupWarningReason: cleanupWarningReason
        )
    }
}

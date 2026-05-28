import Foundation

struct SwitchAccountTarget: Sendable {
    let account: CodexAccount
    let snapshotURL: URL
    let selectedSnapshotMetadata: AuthMetadata
}

struct SwitchAccountRestartPlan: Sendable {
    let shouldRestartCodexApp: Bool
    let preserveEnabled: Bool
}

extension SwitchAccountUseCase {
    func loadSwitchTarget(accountID: UUID, from manifest: AccountManifest) async throws -> SwitchAccountTarget {
        guard let account = manifest.accounts.first(where: { $0.id == accountID }) else {
            throw CodexKeyringError.snapshotMissing(accountID: accountID)
        }

        let snapshotURL = repository.snapshotURL(named: account.snapshotFileName)
        let selectedSnapshotMetadata = try await readSelectedSnapshot(
            from: snapshotURL,
            accountID: account.id
        )

        return SwitchAccountTarget(
            account: account,
            snapshotURL: snapshotURL,
            selectedSnapshotMetadata: selectedSnapshotMetadata
        )
    }

    func makeRestartPlan(restartCodexApp: Bool, manifest: AccountManifest) -> SwitchAccountRestartPlan {
        let shouldRestartCodexApp = restartCodexApp && appController.isRunning
        return SwitchAccountRestartPlan(
            shouldRestartCodexApp: shouldRestartCodexApp,
            preserveEnabled: manifest.settings.preserveAgentPreferencesPerAccount && shouldRestartCodexApp
        )
    }

    func targetPreferences(accountID: UUID, in manifest: AccountManifest) -> AccountAgentPreferences? {
        manifest.accounts.first(where: { $0.id == accountID })?.agentPreferences
    }
}

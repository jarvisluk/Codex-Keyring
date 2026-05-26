import Foundation

/// Load the persisted manifest and sync `activeAccountID` against the current Codex auth file.
public struct RefreshStateUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let authReader: AuthFileReading

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        authReader: AuthFileReading
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
    }

    public func callAsFunction() async throws -> AccountState {
        let manifest = try await repository.load()
        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)

        var activeID = manifest.activeAccountID
        if let fingerprint = currentAuth?.fingerprint,
           let match = manifest.accounts.first(where: { $0.fingerprint == fingerprint }) {
            activeID = match.id
        }

        let needsSync = activeID != manifest.activeAccountID
        let resolvedManifest: AccountManifest
        if needsSync {
            var updated = manifest
            updated.activeAccountID = activeID
            try await repository.save(updated)
            resolvedManifest = updated
        } else {
            resolvedManifest = manifest
        }

        return AccountState(
            accounts: resolvedManifest.accounts,
            activeAccountID: resolvedManifest.activeAccountID,
            settings: resolvedManifest.settings,
            currentAuthMetadata: currentAuth
        )
    }
}

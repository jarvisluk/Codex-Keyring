import Foundation

public struct RemoveAccountResult: Sendable {
    public let state: AccountState
    public let removedAlias: String
}

public struct RemoveAccountUseCase: Sendable {
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

    public func callAsFunction(accountID: UUID) async throws -> RemoveAccountResult {
        var manifest = try await repository.load()
        guard let index = manifest.accounts.firstIndex(where: { $0.id == accountID }) else {
            let currentAuth = try await readLiveAuthIfPresent()
            return RemoveAccountResult(
                state: AccountState(manifest: manifest, currentAuthMetadata: currentAuth),
                removedAlias: ""
            )
        }
        let removed = manifest.accounts[index]
        let originalManifest = manifest
        manifest.accounts.remove(at: index)
        if manifest.activeAccountID == removed.id {
            manifest.activeAccountID = nil
        }

        let currentAuth = try await readLiveAuthIfPresent()
        var activeID = manifest.activeAccountID
        if activeID == nil,
           let currentAuth,
           let match = AccountIdentityMatcher.firstMatchingAccount(for: currentAuth, in: manifest.accounts) {
            activeID = match.id
            manifest.activeAccountID = activeID
        }

        try await repository.save(manifest)
        do {
            try await repository.deleteSnapshot(named: removed.snapshotFileName)
        } catch {
            try await rollbackManifest(to: originalManifest, after: error)
            throw error
        }

        return RemoveAccountResult(
            state: AccountState(manifest: manifest, currentAuthMetadata: currentAuth),
            removedAlias: removed.displayName
        )
    }

    private func readLiveAuthIfPresent() async throws -> AuthMetadata? {
        try await authReader.readIfPresent(from: installer.liveAuthFileURL)
    }

    private func rollbackManifest(to originalManifest: AccountManifest, after originalError: Error) async throws {
        do {
            try await repository.save(originalManifest)
        } catch {
            throw CodexKeyringError.manifestRollbackFailed(
                originalReason: originalError.localizedDescription,
                rollbackReason: error.localizedDescription
            )
        }
    }
}

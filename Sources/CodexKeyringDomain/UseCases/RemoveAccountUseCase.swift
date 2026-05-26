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
            return RemoveAccountResult(
                state: AccountState(
                    accounts: manifest.accounts,
                    activeAccountID: manifest.activeAccountID,
                    settings: manifest.settings,
                    currentAuthMetadata: try? await authReader.read(from: installer.liveAuthFileURL)
                ),
                removedAlias: ""
            )
        }
        let removed = manifest.accounts[index]
        if repository.snapshotExists(named: removed.snapshotFileName) {
            try await repository.deleteSnapshot(named: removed.snapshotFileName)
        }
        manifest.accounts.remove(at: index)
        if manifest.activeAccountID == removed.id {
            manifest.activeAccountID = nil
        }
        try await repository.save(manifest)

        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
        var activeID = manifest.activeAccountID
        if activeID == nil,
           let fingerprint = currentAuth?.fingerprint,
           let match = manifest.accounts.first(where: { $0.fingerprint == fingerprint }) {
            activeID = match.id
            manifest.activeAccountID = activeID
            try await repository.save(manifest)
        }

        return RemoveAccountResult(
            state: AccountState(
                accounts: manifest.accounts,
                activeAccountID: manifest.activeAccountID,
                settings: manifest.settings,
                currentAuthMetadata: currentAuth
            ),
            removedAlias: removed.displayName
        )
    }
}

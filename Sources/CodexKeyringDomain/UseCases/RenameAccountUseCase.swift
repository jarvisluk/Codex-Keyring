import Foundation

public struct RenameAccountResult: Sendable {
    public let state: AccountState
    public let newAlias: String
    public let didRename: Bool
}

public struct RenameAccountUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let authReader: AuthFileReading
    private let clock: Clock
    private let aliasPolicy: AliasPolicy

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        authReader: AuthFileReading,
        clock: Clock = SystemClock(),
        aliasPolicy: AliasPolicy = AliasPolicy()
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.clock = clock
        self.aliasPolicy = aliasPolicy
    }

    public func callAsFunction(
        accountID: UUID,
        newAlias: String
    ) async throws -> RenameAccountResult {
        var manifest = try await repository.load()
        guard let index = manifest.accounts.firstIndex(where: { $0.id == accountID }) else {
            return RenameAccountResult(
                state: await currentState(for: manifest),
                newAlias: newAlias,
                didRename: false
            )
        }

        let existing = manifest.accounts[index]
        let unique = aliasPolicy.renameAlias(
            newAlias,
            for: existing,
            among: manifest.accounts
        )

        if unique == existing.alias {
            return RenameAccountResult(
                state: await currentState(for: manifest),
                newAlias: existing.alias,
                didRename: false
            )
        }

        var updated = existing
        updated.alias = unique
        updated.updatedAt = clock.now()
        manifest.accounts[index] = updated
        manifest.accounts.sort(by: CodexAccount.displayOrderPrecedes)
        try await repository.save(manifest)

        return RenameAccountResult(
            state: await currentState(for: manifest),
            newAlias: unique,
            didRename: true
        )
    }

    private func currentState(for manifest: AccountManifest) async -> AccountState {
        let currentAuth = try? await authReader.readIfPresent(from: installer.liveAuthFileURL)
        return AccountState(manifest: manifest, currentAuthMetadata: currentAuth)
    }
}

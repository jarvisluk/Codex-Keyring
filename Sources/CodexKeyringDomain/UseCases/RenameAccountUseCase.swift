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
                state: AccountState(
                    accounts: manifest.accounts,
                    activeAccountID: manifest.activeAccountID,
                    settings: manifest.settings,
                    currentAuthMetadata: try? await authReader.read(from: installer.liveAuthFileURL)
                ),
                newAlias: newAlias,
                didRename: false
            )
        }

        let existing = manifest.accounts[index]
        let cleaned = aliasPolicy.cleanAllowingEmpty(newAlias)
        let otherAliases = manifest.accounts.enumerated()
            .compactMap { $0.offset == index ? nil : $0.element.alias }
        let unique = cleaned.isEmpty
            ? cleaned
            : aliasPolicy.uniquified(cleaned, existingAliases: otherAliases)

        if unique == existing.alias {
            let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
            return RenameAccountResult(
                state: AccountState(
                    accounts: manifest.accounts,
                    activeAccountID: manifest.activeAccountID,
                    settings: manifest.settings,
                    currentAuthMetadata: currentAuth
                ),
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

        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
        return RenameAccountResult(
            state: AccountState(
                accounts: manifest.accounts,
                activeAccountID: manifest.activeAccountID,
                settings: manifest.settings,
                currentAuthMetadata: currentAuth
            ),
            newAlias: unique,
            didRename: true
        )
    }
}

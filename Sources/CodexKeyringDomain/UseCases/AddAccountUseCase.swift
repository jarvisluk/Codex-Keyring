import Foundation

public struct AddAccountResult: Sendable {
    public let state: AccountState
    public let savedAlias: String
    public let wasUpdate: Bool
}

/// Parse an auth file, then add it as a new snapshot or update an existing one
/// (matched by fingerprint).
public struct AddAccountUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let authReader: AuthFileReading
    private let preferencesPort: CodexAgentPreferencesPorting
    private let clock: Clock
    private let aliasPolicy: AliasPolicy

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        authReader: AuthFileReading,
        preferencesPort: CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort(),
        clock: Clock = SystemClock(),
        aliasPolicy: AliasPolicy = AliasPolicy()
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.preferencesPort = preferencesPort
        self.clock = clock
        self.aliasPolicy = aliasPolicy
    }

    public func callAsFunction(
        sourceURL: URL,
        requestedAlias: String?,
        activate: Bool = true
    ) async throws -> AddAccountResult {
        let metadata = try await authReader.read(from: sourceURL)
        var manifest = try await repository.load()
        let now = clock.now()
        let suggested = aliasPolicy.suggested(for: metadata)
        let cleaned = aliasPolicy.clean(requestedAlias, fallback: suggested)

        // Only capture preferences when this add operation owns the live Codex
        // state: i.e. we're activating, and the source IS the live auth file.
        // Otherwise the captured preferences belong to whoever currently owns
        // ~/.codex/, not to the new snapshot.
        let initialPreferences: AccountAgentPreferences? = await {
            guard activate, sourceURL == installer.liveAuthFileURL else { return nil }
            let captured = try? await preferencesPort.captureCurrent()
            return (captured?.isEmpty == false) ? captured : nil
        }()

        if let index = manifest.accounts.firstIndex(where: { $0.fingerprint == metadata.fingerprint }) {
            let existing = manifest.accounts[index]
            _ = try await repository.writeSnapshot(from: sourceURL, for: existing.id)
            var updated = existing
            updated.alias = cleaned
            updated.email = metadata.email
            updated.plan = metadata.plan
            updated.authMode = metadata.authMode
            updated.accountIdentifier = metadata.accountIdentifier
            updated.tokenExpiresAt = metadata.tokenExpiresAt
            updated.updatedAt = now
            if let initialPreferences {
                updated.agentPreferences = initialPreferences
            }
            manifest.accounts[index] = updated
            if activate {
                manifest.activeAccountID = updated.id
            }
            try await repository.save(manifest)

            let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
            return AddAccountResult(
                state: AccountState(
                    accounts: sorted(manifest.accounts),
                    activeAccountID: manifest.activeAccountID,
                    settings: manifest.settings,
                    currentAuthMetadata: currentAuth
                ),
                savedAlias: updated.alias,
                wasUpdate: true
            )
        }

        let id = UUID()
        let existingAliases = manifest.accounts.map { $0.alias }
        let uniqueAlias = aliasPolicy.uniquified(cleaned, existingAliases: existingAliases)
        let snapshotName = try await repository.writeSnapshot(from: sourceURL, for: id)
        let account = CodexAccount(
            id: id,
            alias: uniqueAlias,
            email: metadata.email,
            plan: metadata.plan,
            authMode: metadata.authMode,
            accountIdentifier: metadata.accountIdentifier,
            snapshotFileName: snapshotName,
            fingerprint: metadata.fingerprint,
            createdAt: now,
            updatedAt: now,
            tokenExpiresAt: metadata.tokenExpiresAt,
            agentPreferences: initialPreferences
        )
        manifest.accounts.append(account)
        manifest.accounts = sorted(manifest.accounts)
        if activate {
            manifest.activeAccountID = account.id
        }
        try await repository.save(manifest)

        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
        return AddAccountResult(
            state: AccountState(
                accounts: manifest.accounts,
                activeAccountID: manifest.activeAccountID,
                settings: manifest.settings,
                currentAuthMetadata: currentAuth
            ),
            savedAlias: account.alias,
            wasUpdate: false
        )
    }

    private func sorted(_ accounts: [CodexAccount]) -> [CodexAccount] {
        accounts.sorted { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
    }
}

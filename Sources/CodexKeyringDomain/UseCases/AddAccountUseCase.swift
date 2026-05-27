import Foundation

public struct AddAccountResult: Sendable {
    public let state: AccountState
    public let savedAlias: String
    public let wasUpdate: Bool
    public let agentPreferencesWarningReason: String?
}

/// Parse an auth file, then add it as a new snapshot or update an existing one
/// (matched by fingerprint, then stable OAuth account identifier).
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
        activate: Bool
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
        let initialPreferenceCapture: (
            preferences: AccountAgentPreferences?,
            warningReason: String?
        )
        if manifest.settings.preserveAgentPreferencesPerAccount,
           activate,
           sourceURL == installer.liveAuthFileURL
        {
            do {
                let captured = try await preferencesPort.captureCurrent()
                initialPreferenceCapture = (captured.isEmpty ? nil : captured, nil)
            } catch {
                initialPreferenceCapture = (nil, error.localizedDescription)
            }
        } else {
            initialPreferenceCapture = (nil, nil)
        }
        let initialPreferences = initialPreferenceCapture.preferences
        let agentPreferencesWarningReason = initialPreferenceCapture.warningReason

        if let index = AccountIdentityMatcher.firstMatchingIndex(for: metadata, in: manifest.accounts) {
            let originalManifest = manifest
            let existing = manifest.accounts[index]
            let requestedUpdateAlias = requestedAlias?.trimmingCharacters(in: .whitespacesAndNewlines)
            let updateAlias = if requestedUpdateAlias?.isEmpty == false {
                cleaned
            } else {
                existing.alias
            }
            let otherAliases = manifest.accounts.enumerated().compactMap { offset, account in
                offset == index ? nil : account.alias
            }
            let uniqueAlias = aliasPolicy.uniquified(updateAlias, existingAliases: otherAliases)
            var updated = AuthMetadataMergePolicy().merged(metadata, into: existing)
            updated.alias = uniqueAlias
            updated.updatedAt = now
            if let initialPreferences {
                updated.agentPreferences = initialPreferences
            }
            manifest.accounts[index] = updated
            if activate {
                manifest.activeAccountID = updated.id
            }
            manifest.accounts = sorted(manifest.accounts)
            try await repository.save(manifest)
            do {
                _ = try await repository.writeSnapshot(from: sourceURL, for: existing.id)
            } catch {
                try await rollbackManifest(to: originalManifest, after: error)
                throw error
            }

            let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
            return AddAccountResult(
                state: AccountState(
                    accounts: sorted(manifest.accounts),
                    activeAccountID: manifest.activeAccountID,
                    settings: manifest.settings,
                    currentAuthMetadata: currentAuth
                ),
                savedAlias: updated.alias,
                wasUpdate: true,
                agentPreferencesWarningReason: agentPreferencesWarningReason
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
        do {
            try await repository.save(manifest)
        } catch {
            try await cleanupSnapshot(named: snapshotName, after: error)
            throw error
        }

        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
        return AddAccountResult(
            state: AccountState(
                accounts: manifest.accounts,
                activeAccountID: manifest.activeAccountID,
                settings: manifest.settings,
                currentAuthMetadata: currentAuth
            ),
            savedAlias: account.alias,
            wasUpdate: false,
            agentPreferencesWarningReason: agentPreferencesWarningReason
        )
    }

    private func sorted(_ accounts: [CodexAccount]) -> [CodexAccount] {
        accounts.sorted(by: CodexAccount.displayOrderPrecedes)
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

    private func cleanupSnapshot(named snapshotName: String, after originalError: Error) async throws {
        do {
            try await repository.deleteSnapshot(named: snapshotName)
        } catch {
            throw CodexKeyringError.snapshotCleanupFailed(
                originalReason: originalError.localizedDescription,
                cleanupReason: error.localizedDescription,
                snapshotFileName: snapshotName
            )
        }
    }
}

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
    let repository: AccountRepository
    let installer: CodexAuthInstalling
    let authReader: AuthFileReading
    let preferencesPort: CodexAgentPreferencesPorting
    let clock: Clock
    let aliasPolicy: AliasPolicy

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
        let manifest = try await repository.load()
        let now = clock.now()
        let suggested = aliasPolicy.suggested(for: metadata)
        let cleaned = aliasPolicy.clean(requestedAlias, fallback: suggested)

        let initialPreferenceCapture = await captureInitialPreferences(
            manifest: manifest,
            sourceURL: sourceURL,
            activate: activate
        )
        let mutationRequest = AddAccountMutationRequest(
            metadata: metadata,
            manifest: manifest,
            sourceURL: sourceURL,
            requestedAlias: requestedAlias,
            cleanedAlias: cleaned,
            initialPreferences: initialPreferenceCapture.preferences,
            agentPreferencesWarningReason: initialPreferenceCapture.warningReason,
            now: now,
            activate: activate
        )

        if let index = AccountIdentityMatcher.firstMatchingIndex(for: metadata, in: manifest.accounts) {
            return try await updateExistingAccount(
                at: index,
                request: mutationRequest
            )
        }

        return try await createAccount(request: mutationRequest)
    }
}

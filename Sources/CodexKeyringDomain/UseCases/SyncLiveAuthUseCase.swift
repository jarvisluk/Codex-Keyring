import Foundation

public struct SyncLiveAuthResult: Sendable, Equatable {
    /// Account whose snapshot/metadata was just updated to match the live file.
    public let updatedAccountID: UUID?
    /// True when the live auth fingerprint moved (i.e. snapshot bytes were
    /// rewritten with a fresher refresh-token rotation).
    public let didUpdateSnapshot: Bool
    /// True when the manifest's `activeAccountID` was reconciled against the
    /// live file (e.g. user switched accounts outside this app).
    public let didReassignActive: Bool

    public init(
        updatedAccountID: UUID?,
        didUpdateSnapshot: Bool,
        didReassignActive: Bool
    ) {
        self.updatedAccountID = updatedAccountID
        self.didUpdateSnapshot = didUpdateSnapshot
        self.didReassignActive = didReassignActive
    }

    public static let noop = SyncLiveAuthResult(
        updatedAccountID: nil,
        didUpdateSnapshot: false,
        didReassignActive: false
    )
}

/// Keep saved snapshots in lock-step with `~/.codex/auth.json` so a rotating
/// OAuth refresh token never goes stale.
///
/// Codex App consumes the live auth's refresh token, gets a new one from the
/// OpenAI auth server, and writes it back to `~/.codex/auth.json`. The
/// previously saved snapshot still has the old (now invalidated) refresh
/// token; switching back to it would surface
/// "Your refresh token was already used". Calling this use case after any
/// change to the live file copies it back to the matching account snapshot.
public struct SyncLiveAuthUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let authReader: AuthFileReading
    private let clock: Clock

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        authReader: AuthFileReading,
        clock: Clock = SystemClock()
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction() async throws -> SyncLiveAuthResult {
        guard let live = try? await authReader.read(from: installer.liveAuthFileURL) else {
            return .noop
        }
        var manifest = try await repository.load()
        return try await sync(liveMetadata: live, liveURL: installer.liveAuthFileURL, manifest: &manifest)
    }

    /// Variant used by call sites that already loaded a manifest and just need
    /// the in-place reconciliation. The manifest is updated and persisted
    /// whenever something changes.
    @discardableResult
    public func sync(
        liveMetadata live: AuthMetadata,
        liveURL: URL,
        manifest: inout AccountManifest
    ) async throws -> SyncLiveAuthResult {
        guard let match = match(for: live, in: manifest) else {
            return .noop
        }

        var didUpdateSnapshot = false
        if match.fingerprint != live.fingerprint {
            _ = try await repository.writeSnapshot(from: liveURL, for: match.id)
            if let index = manifest.accounts.firstIndex(where: { $0.id == match.id }) {
                var updated = manifest.accounts[index]
                updated.fingerprint = live.fingerprint
                updated.email = live.email.isEmpty ? updated.email : live.email
                updated.plan = live.plan.isEmpty ? updated.plan : live.plan
                updated.authMode = live.authMode.isEmpty ? updated.authMode : live.authMode
                updated.accountIdentifier = live.accountIdentifier.isEmpty
                    ? updated.accountIdentifier
                    : live.accountIdentifier
                updated.tokenExpiresAt = live.tokenExpiresAt
                updated.updatedAt = clock.now()
                manifest.accounts[index] = updated
            }
            didUpdateSnapshot = true
        }

        var didReassignActive = false
        if manifest.activeAccountID != match.id {
            manifest.activeAccountID = match.id
            didReassignActive = true
        }

        if didUpdateSnapshot || didReassignActive {
            try await repository.save(manifest)
        }

        return SyncLiveAuthResult(
            updatedAccountID: match.id,
            didUpdateSnapshot: didUpdateSnapshot,
            didReassignActive: didReassignActive
        )
    }

    /// Locate the saved account that the current live auth most likely
    /// belongs to. Preference order:
    ///   1. Exact fingerprint match (no token rotation has happened).
    ///   2. Same stable OAuth `accountIdentifier` (token has been rotated by
    ///      Codex App – we still know which saved account this belongs to).
    private func match(for live: AuthMetadata, in manifest: AccountManifest) -> CodexAccount? {
        if let exact = manifest.accounts.first(where: { $0.fingerprint == live.fingerprint }) {
            return exact
        }
        let identifier = live.accountIdentifier
        guard SyncLiveAuthUseCase.isStable(identifier: identifier) else {
            return nil
        }
        return manifest.accounts.first { account in
            account.accountIdentifier == identifier
                && SyncLiveAuthUseCase.isStable(identifier: account.accountIdentifier)
        }
    }

    /// `AuthMetadataParser` falls back to `"api-key"` when the OAuth account_id
    /// is unavailable. That value is shared across every API-key auth file, so
    /// it isn't safe to treat as a unique identity for snapshot syncing.
    private static func isStable(identifier: String) -> Bool {
        !identifier.isEmpty && identifier != "api-key"
    }
}

import Foundation

public struct SyncLiveAuthResult: Sendable, Equatable {
    /// Account whose snapshot/metadata was just updated to match the live file.
    public let updatedAccountID: UUID?
    /// True when the live auth fingerprint moved (i.e. snapshot bytes were
    /// rewritten with a fresher refresh-token rotation).
    public let didUpdateSnapshot: Bool
    /// True when the saved manifest metadata was refreshed from the live auth
    /// without necessarily rewriting the snapshot bytes.
    public let didUpdateMetadata: Bool
    /// True when the manifest's `activeAccountID` was reconciled against the
    /// live file (e.g. user switched accounts outside this app).
    public let didReassignActive: Bool

    public init(
        updatedAccountID: UUID?,
        didUpdateSnapshot: Bool,
        didUpdateMetadata: Bool = false,
        didReassignActive: Bool
    ) {
        self.updatedAccountID = updatedAccountID
        self.didUpdateSnapshot = didUpdateSnapshot
        self.didUpdateMetadata = didUpdateMetadata
        self.didReassignActive = didReassignActive
    }

    public static let noop = SyncLiveAuthResult(
        updatedAccountID: nil,
        didUpdateSnapshot: false,
        didUpdateMetadata: false,
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
        guard let live = try await readLiveAuthIfPresent() else {
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
        guard let match = AccountIdentityMatcher.firstMatchingAccount(for: live, in: manifest.accounts) else {
            return .noop
        }

        var didUpdateSnapshot = false
        var didUpdateMetadata = false
        let shouldRewriteSnapshot = match.fingerprint != live.fingerprint
        if shouldRewriteSnapshot {
            _ = try await repository.writeSnapshot(from: liveURL, for: match.id)
            didUpdateSnapshot = true
        }

        if let index = manifest.accounts.firstIndex(where: { $0.id == match.id }) {
            let original = manifest.accounts[index]
            var updated = AuthMetadataMergePolicy().merged(live, into: original)
            if updated != original {
                updated.updatedAt = clock.now()
                manifest.accounts[index] = updated
                didUpdateMetadata = true
            }
        }

        var didReassignActive = false
        if manifest.activeAccountID != match.id {
            manifest.activeAccountID = match.id
            didReassignActive = true
        }

        if didUpdateSnapshot || didUpdateMetadata || didReassignActive {
            try await repository.save(manifest)
        }

        return SyncLiveAuthResult(
            updatedAccountID: match.id,
            didUpdateSnapshot: didUpdateSnapshot,
            didUpdateMetadata: didUpdateMetadata,
            didReassignActive: didReassignActive
        )
    }

    private func readLiveAuthIfPresent() async throws -> AuthMetadata? {
        do {
            return try await authReader.read(from: installer.liveAuthFileURL)
        } catch CodexKeyringError.authFileMissing {
            return nil
        }
    }
}

import Foundation

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
    let repository: AccountRepository
    let installer: CodexAuthInstalling
    let authReader: AuthFileReading
    let clock: Clock

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
}

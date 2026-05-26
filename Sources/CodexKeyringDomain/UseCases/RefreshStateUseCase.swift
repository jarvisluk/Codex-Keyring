import Foundation

/// Load the persisted manifest and sync `activeAccountID` against the current Codex auth file.
public struct RefreshStateUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let authReader: AuthFileReading
    private let syncLiveAuth: SyncLiveAuthUseCase

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        authReader: AuthFileReading,
        clock: Clock = SystemClock()
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.syncLiveAuth = SyncLiveAuthUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            clock: clock
        )
    }

    public func callAsFunction() async throws -> AccountState {
        var manifest = try await repository.load()
        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)

        // Keep the saved snapshot for whichever account currently owns the
        // live auth file in lock-step with the live bytes. This is how we
        // capture the rotating OAuth refresh token before Codex App's next
        // refresh invalidates whatever copy we already had on disk.
        if let currentAuth {
            _ = try? await syncLiveAuth.sync(
                liveMetadata: currentAuth,
                liveURL: installer.liveAuthFileURL,
                manifest: &manifest
            )
        }

        let refreshedMetadata: AuthMetadata?
        if currentAuth != nil {
            refreshedMetadata = try? await authReader.read(from: installer.liveAuthFileURL)
        } else {
            refreshedMetadata = nil
        }

        return AccountState(
            accounts: manifest.accounts,
            activeAccountID: manifest.activeAccountID,
            settings: manifest.settings,
            currentAuthMetadata: refreshedMetadata
        )
    }
}

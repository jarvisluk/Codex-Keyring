import Foundation

/// Validate the saved snapshot, back up the current Codex auth, replace it,
/// re-parse the live file, and optionally restart Codex App. When the user has
/// enabled per-account agent preferences, the outgoing account's preferences
/// are re-captured first and the incoming account's preferences are applied
/// while Codex App is between terminate and relaunch.
public struct SwitchAccountUseCase: Sendable {
    let repository: AccountRepository
    let installer: CodexAuthInstalling
    let authReader: AuthFileReading
    let appController: CodexAppControlling
    let preferencesPort: CodexAgentPreferencesPorting
    let syncLiveAuth: SyncLiveAuthUseCase

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        authReader: AuthFileReading,
        appController: CodexAppControlling,
        preferencesPort: CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort(),
        clock: Clock = SystemClock()
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.appController = appController
        self.preferencesPort = preferencesPort
        self.syncLiveAuth = SyncLiveAuthUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            clock: clock
        )
    }

}

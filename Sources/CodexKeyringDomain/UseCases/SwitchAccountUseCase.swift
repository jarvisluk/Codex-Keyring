import Foundation

public struct SwitchAccountResult: Sendable {
    public let state: AccountState
    public let switchedAlias: String
    public let restartOutcome: CodexAppRestartOutcome?
    /// True when the live auth file was already this account's; no backup/replace happened.
    public let wasAlreadyActive: Bool
}

/// Validate the saved snapshot, back up the current Codex auth, replace it,
/// re-parse the live file, and optionally restart Codex App.
public struct SwitchAccountUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let authReader: AuthFileReading
    private let appController: CodexAppControlling

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        authReader: AuthFileReading,
        appController: CodexAppControlling
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.appController = appController
    }

    public func callAsFunction(
        accountID: UUID,
        restartCodexApp: Bool
    ) async throws -> SwitchAccountResult {
        var manifest = try await repository.load()
        guard let account = manifest.accounts.first(where: { $0.id == accountID }) else {
            throw CodexKeyringError.snapshotMissing(accountID: accountID)
        }
        guard repository.snapshotExists(named: account.snapshotFileName) else {
            throw CodexKeyringError.snapshotMissing(accountID: account.id)
        }

        let snapshotURL = repository.snapshotURL(named: account.snapshotFileName)
        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)
        let wasAlreadyActive = currentAuth?.fingerprint == account.fingerprint

        if !wasAlreadyActive {
            do {
                _ = try await installer.backupCurrent()
            } catch {
                throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
            }
            try await installer.install(snapshot: snapshotURL)
        }

        manifest.activeAccountID = account.id
        try await repository.save(manifest)

        let refreshedAuth = try? await authReader.read(from: installer.liveAuthFileURL)

        var restartOutcome: CodexAppRestartOutcome?
        if restartCodexApp {
            do {
                restartOutcome = try await appController.restartIfRunning()
            } catch {
                throw CodexKeyringError.codexAppRelaunchFailed(reason: error.localizedDescription)
            }
        }

        return SwitchAccountResult(
            state: AccountState(
                accounts: manifest.accounts,
                activeAccountID: manifest.activeAccountID,
                settings: manifest.settings,
                currentAuthMetadata: refreshedAuth
            ),
            switchedAlias: account.displayName,
            restartOutcome: restartOutcome,
            wasAlreadyActive: wasAlreadyActive
        )
    }
}

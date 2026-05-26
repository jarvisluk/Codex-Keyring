import Foundation

public struct SwitchAccountResult: Sendable {
    public let state: AccountState
    public let switchedAlias: String
    public let restartOutcome: CodexAppRestartOutcome?
    /// True when the live auth file was already this account's; no backup/replace happened.
    public let wasAlreadyActive: Bool
    /// True when per-account agent preferences were applied to the local Codex
    /// state files as part of this switch.
    public let appliedAgentPreferences: Bool
}

/// Validate the saved snapshot, back up the current Codex auth, replace it,
/// re-parse the live file, and optionally restart Codex App. When the user has
/// enabled per-account agent preferences, the outgoing account's preferences
/// are re-captured first and the incoming account's preferences are applied
/// while Codex App is between terminate and relaunch.
public struct SwitchAccountUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let authReader: AuthFileReading
    private let appController: CodexAppControlling
    private let preferencesPort: CodexAgentPreferencesPorting
    private let syncLiveAuth: SyncLiveAuthUseCase

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

        let currentAuth = try? await authReader.read(from: installer.liveAuthFileURL)

        // Before we overwrite ~/.codex/auth.json, copy whatever Codex App has
        // most recently written there back into the matching saved snapshot.
        // Otherwise the refresh token we hand back to that account next time
        // will already have been rotated out by the server.
        if let currentAuth {
            _ = try? await syncLiveAuth.sync(
                liveMetadata: currentAuth,
                liveURL: installer.liveAuthFileURL,
                manifest: &manifest
            )
        }

        let wasAlreadyActive: Bool = {
            guard let live = currentAuth else { return false }
            return manifest.accounts.first(where: { $0.id == account.id })?.fingerprint == live.fingerprint
        }()

        let shouldRestartCodexApp = restartCodexApp && appController.isRunning
        let preserveEnabled = manifest.settings.preserveAgentPreferencesPerAccount && shouldRestartCodexApp

        // Capture the OUTGOING account's current Codex agent preferences so
        // any tweaks the user made in Codex App (model, effort, agent-mode,
        // approval/sandbox, skip-full-access-confirm) carry over the next time
        // they switch back. We only do this when the feature is on and Codex
        // App is currently running, so the switch will restart it; otherwise
        // the captured snapshot could be stale by the time Codex App next
        // quits and rewrites the files.
        if preserveEnabled,
           !wasAlreadyActive,
           let previousActiveID = manifest.activeAccountID,
           let previousIdx = manifest.accounts.firstIndex(where: { $0.id == previousActiveID })
        {
            if let captured = try? await preferencesPort.captureCurrent(), !captured.isEmpty {
                manifest.accounts[previousIdx].agentPreferences = captured
            }
        }

        let snapshotURL = repository.snapshotURL(named: account.snapshotFileName)

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

        let targetPreferences = manifest.accounts
            .first(where: { $0.id == account.id })?
            .agentPreferences

        let refreshedAuth = try? await authReader.read(from: installer.liveAuthFileURL)

        var restartOutcome: CodexAppRestartOutcome?
        var appliedAgentPreferences = false

        if restartCodexApp {
            let shouldApply = preserveEnabled
                && !wasAlreadyActive
                && targetPreferences?.isEmpty == false
            let prefsToApply = shouldApply ? targetPreferences : nil

            if shouldRestartCodexApp {
                do {
                    restartOutcome = try await appController.restartIfRunning {
                        let projectArrangement = (try? await preferencesPort.captureProjectArrangement())
                            ?? CodexProjectArrangement()
                        if let prefs = prefsToApply {
                            try await preferencesPort.apply(prefs)
                        }
                        if !projectArrangement.isEmpty {
                            try await preferencesPort.restoreProjectArrangement(projectArrangement)
                        }
                    }
                } catch {
                    throw CodexKeyringError.codexAppRelaunchFailed(reason: error.localizedDescription)
                }
            } else {
                restartOutcome = .wasNotRunning
            }

            if let restartOutcome,
               case .relaunched = restartOutcome,
               prefsToApply != nil
            {
                appliedAgentPreferences = true
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
            wasAlreadyActive: wasAlreadyActive,
            appliedAgentPreferences: appliedAgentPreferences
        )
    }
}

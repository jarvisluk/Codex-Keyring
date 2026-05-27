import Foundation

public struct SwitchAccountResult: Sendable {
    public let state: AccountState
    public let switchedAlias: String
    public let restartOutcome: CodexAppRestartOutcome?
    public let restartFailureReason: String?
    /// True when the live auth file was already this account's; no backup/replace happened.
    public let wasAlreadyActive: Bool
    /// True when per-account agent preferences were applied to the local Codex
    /// state files as part of this switch.
    public let appliedAgentPreferences: Bool
    /// Non-fatal warning when the switch succeeded but a best-effort agent
    /// preferences step could not be completed.
    public let agentPreferencesWarningReason: String?
    /// Non-fatal warning when the switch succeeded but the local Codex
    /// project/sidebar arrangement could not be preserved around the restart.
    public let projectArrangementWarningReason: String?
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
        let snapshotURL = repository.snapshotURL(named: account.snapshotFileName)
        let selectedSnapshotMetadata = try await readSelectedSnapshot(
            from: snapshotURL,
            accountID: account.id
        )

        let currentAuth = try await readLiveAuthIfPresent()

        // Before we overwrite ~/.codex/auth.json, copy whatever Codex App has
        // most recently written there back into the matching saved snapshot.
        // Otherwise the refresh token we hand back to that account next time
        // will already have been rotated out by the server.
        if let currentAuth {
            do {
                _ = try await syncLiveAuth.sync(
                    liveMetadata: currentAuth,
                    liveURL: installer.liveAuthFileURL,
                    manifest: &manifest
                )
            } catch {
                throw CodexKeyringError.currentAuthSyncFailed(reason: error.localizedDescription)
            }
        }

        let wasAlreadyActive: Bool = {
            guard let live = currentAuth else { return false }
            return manifest.accounts.first(where: { $0.id == account.id })?.fingerprint == live.fingerprint
        }()

        let shouldRestartCodexApp = restartCodexApp && appController.isRunning
        let preserveEnabled = manifest.settings.preserveAgentPreferencesPerAccount && shouldRestartCodexApp
        let warningBox = SwitchAccountWarningBox()

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
            do {
                let captured = try await preferencesPort.captureCurrent()
                if !captured.isEmpty {
                    manifest.accounts[previousIdx].agentPreferences = captured
                }
            } catch {
                warningBox.recordAgentPreferencesWarning(error.localizedDescription)
            }
        }

        var restoreURL: URL?
        var didInstallSnapshot = false

        if !wasAlreadyActive {
            do {
                restoreURL = try await installer.backupCurrent()
            } catch let error as CodexKeyringError {
                if case .backupFailed = error {
                    throw error
                }
                throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
            } catch {
                throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
            }
            try await installer.install(snapshot: snapshotURL)
            didInstallSnapshot = true
        }

        manifest.activeAccountID = account.id
        do {
            try await repository.save(manifest)
        } catch {
            if didInstallSnapshot {
                try await restorePreviousLiveAuth(from: restoreURL, after: error)
            }
            throw error
        }

        let targetPreferences = manifest.accounts
            .first(where: { $0.id == account.id })?
            .agentPreferences

        let refreshedAuth = wasAlreadyActive ? currentAuth : selectedSnapshotMetadata

        var restartOutcome: CodexAppRestartOutcome?
        var restartFailureReason: String?

        if restartCodexApp {
            let shouldApply = preserveEnabled
                && !wasAlreadyActive
                && targetPreferences?.isEmpty == false
            let prefsToApply = shouldApply ? targetPreferences : nil

            if shouldRestartCodexApp {
                do {
                    restartOutcome = try await appController.restartIfRunning {
                        let projectArrangement: CodexProjectArrangement
                        do {
                            projectArrangement = try await preferencesPort.captureProjectArrangement()
                        } catch {
                            projectArrangement = CodexProjectArrangement()
                            warningBox.recordProjectArrangementWarning(error.localizedDescription)
                        }
                        if let prefs = prefsToApply {
                            do {
                                try await preferencesPort.apply(prefs)
                                warningBox.recordAppliedAgentPreferences()
                            } catch {
                                warningBox.recordAgentPreferencesWarning(error.localizedDescription)
                            }
                        }
                        if !projectArrangement.isEmpty {
                            do {
                                try await preferencesPort.restoreProjectArrangement(projectArrangement)
                            } catch {
                                warningBox.recordProjectArrangementWarning(error.localizedDescription)
                            }
                        }
                    }
                } catch {
                    restartFailureReason = Self.codexAppRestartFailureReason(from: error)
                }
            } else {
                restartOutcome = .wasNotRunning
            }

        }

        let appliedAgentPreferences: Bool
        if let restartOutcome, case .relaunched = restartOutcome {
            appliedAgentPreferences = warningBox.appliedAgentPreferences
        } else {
            appliedAgentPreferences = false
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
            restartFailureReason: restartFailureReason,
            wasAlreadyActive: wasAlreadyActive,
            appliedAgentPreferences: appliedAgentPreferences,
            agentPreferencesWarningReason: warningBox.agentPreferencesWarningReason,
            projectArrangementWarningReason: warningBox.projectArrangementWarningReason
        )
    }

    private static func codexAppRestartFailureReason(from error: Error) -> String {
        if case CodexKeyringError.codexAppRelaunchFailed(let reason) = error {
            return reason
        }
        return error.localizedDescription
    }

    private func readLiveAuthIfPresent() async throws -> AuthMetadata? {
        do {
            return try await authReader.read(from: installer.liveAuthFileURL)
        } catch CodexKeyringError.authFileMissing {
            return nil
        }
    }

    private func readSelectedSnapshot(from url: URL, accountID: UUID) async throws -> AuthMetadata {
        do {
            return try await authReader.read(from: url)
        } catch CodexKeyringError.authFileMissing {
            throw CodexKeyringError.snapshotMissing(accountID: accountID)
        }
    }

    private func restorePreviousLiveAuth(from restoreURL: URL?, after originalError: Error) async throws {
        do {
            try await installer.restoreLiveAuth(from: restoreURL)
        } catch {
            let reason = "Manifest save failed after installing the selected account: "
                + "\(originalError.localizedDescription). Previous auth restore failed: "
                + error.localizedDescription
            throw CodexKeyringError.previousAuthRestoreFailed(
                reason: reason,
                recoveryPath: restoreURL?.path
            )
        }
    }
}

private final class SwitchAccountWarningBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _agentPreferencesWarningReason: String?
    private var _projectArrangementWarningReason: String?
    private var _appliedAgentPreferences = false

    var agentPreferencesWarningReason: String? {
        lock.withLock { _agentPreferencesWarningReason }
    }

    var projectArrangementWarningReason: String? {
        lock.withLock { _projectArrangementWarningReason }
    }

    var appliedAgentPreferences: Bool {
        lock.withLock { _appliedAgentPreferences }
    }

    func recordAgentPreferencesWarning(_ reason: String) {
        lock.withLock {
            if _agentPreferencesWarningReason == nil {
                _agentPreferencesWarningReason = reason
            }
        }
    }

    func recordProjectArrangementWarning(_ reason: String) {
        lock.withLock {
            if _projectArrangementWarningReason == nil {
                _projectArrangementWarningReason = reason
            }
        }
    }

    func recordAppliedAgentPreferences() {
        lock.withLock {
            _appliedAgentPreferences = true
        }
    }
}

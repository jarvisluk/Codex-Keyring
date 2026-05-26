import Foundation
import CodexKeyringDomain

public struct AccountStorageLocations: Sendable {
    public let codexAuthPath: String
    public let applicationSupportPath: String
    public let accountsDirectoryPath: String
    public let backupsDirectoryPath: String
    public let logsDirectoryPath: String
    public let currentLogFilePath: String

    public init(
        codexAuthPath: String,
        applicationSupportPath: String,
        accountsDirectoryPath: String,
        backupsDirectoryPath: String,
        logsDirectoryPath: String,
        currentLogFilePath: String
    ) {
        self.codexAuthPath = codexAuthPath
        self.applicationSupportPath = applicationSupportPath
        self.accountsDirectoryPath = accountsDirectoryPath
        self.backupsDirectoryPath = backupsDirectoryPath
        self.logsDirectoryPath = logsDirectoryPath
        self.currentLogFilePath = currentLogFilePath
    }
}

@MainActor
public final class AccountStore: ObservableObject {
    @Published public private(set) var accounts: [CodexAccount] = []
    @Published public private(set) var activeAccountID: UUID?
    @Published public private(set) var currentAuthMetadata: AuthMetadata?
    @Published public private(set) var isRefreshInProgress = false
    @Published public private(set) var isLoginInProgress = false
    @Published public private(set) var settings = AppSettings()
    @Published public var statusMessage: String = "Ready."
    @Published public var lastError: String?

    public let storageLocations: AccountStorageLocations
    public let isLaunchAtLoginSupported: Bool

    private let installer: any CodexAuthInstalling
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let openAuthURL: @Sendable (URL) async throws -> Void
    private let logService: (any AppLogService)?
    private let liveAuthWatcher: any LiveAuthWatching

    private let refreshState: RefreshStateUseCase
    private let addAccount: AddAccountUseCase
    private let switchAccount: SwitchAccountUseCase
    private let removeAccount: RemoveAccountUseCase
    private let renameAccount: RenameAccountUseCase
    private let updateSettings: UpdateSettingsUseCase
    private let loginNewAccount: LoginNewAccountUseCase
    private let syncLiveAuthUseCase: SyncLiveAuthUseCase

    public init(
        repository: any AccountRepository,
        installer: any CodexAuthInstalling,
        authReader: any AuthFileReading,
        appController: any CodexAppControlling,
        launchAtLoginController: any LaunchAtLoginControlling,
        loginService: any CodexLoginServicing,
        agentPreferencesPort: any CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort(),
        storageLocations: AccountStorageLocations,
        openAuthURL: @escaping @Sendable (URL) async throws -> Void,
        logService: (any AppLogService)? = nil,
        liveAuthWatcher: any LiveAuthWatching = NoopLiveAuthWatcher()
    ) {
        self.installer = installer
        self.launchAtLoginController = launchAtLoginController
        self.storageLocations = storageLocations
        self.openAuthURL = openAuthURL
        self.logService = logService
        self.liveAuthWatcher = liveAuthWatcher
        self.isLaunchAtLoginSupported = launchAtLoginController.isSupported
        self.refreshState = RefreshStateUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        self.addAccount = AddAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            preferencesPort: agentPreferencesPort
        )
        self.switchAccount = SwitchAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            appController: appController,
            preferencesPort: agentPreferencesPort
        )
        self.removeAccount = RemoveAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        self.renameAccount = RenameAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        self.updateSettings = UpdateSettingsUseCase(repository: repository)
        self.loginNewAccount = LoginNewAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            loginService: loginService,
            preferencesPort: agentPreferencesPort
        )
        self.syncLiveAuthUseCase = SyncLiveAuthUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        self.settings.launchAtLogin = launchAtLoginController.isEnabled
        logService?.info("AccountStore initialised; launch-at-login supported=\(launchAtLoginController.isSupported)")
        refresh()
        startLiveAuthWatcher()
    }

    deinit {
        liveAuthWatcher.stop()
    }

    public var activeAccount: CodexAccount? {
        AccountState(
            accounts: accounts,
            activeAccountID: activeAccountID,
            settings: settings,
            currentAuthMetadata: currentAuthMetadata
        ).activeAccount
    }

    public var savedAccountForCurrentAuth: CodexAccount? {
        guard let currentAuthMetadata else { return nil }
        if let exact = accounts.first(where: { $0.fingerprint == currentAuthMetadata.fingerprint }) {
            return exact
        }

        let identifier = currentAuthMetadata.accountIdentifier
        guard isStableAccountIdentifier(identifier) else { return nil }
        return accounts.first { account in
            account.accountIdentifier == identifier
                && isStableAccountIdentifier(account.accountIdentifier)
        }
    }

    public var canSaveCurrentAuth: Bool {
        currentAuthMetadata != nil && savedAccountForCurrentAuth == nil
    }

    public func refresh() {
        guard !isRefreshInProgress else { return }
        isRefreshInProgress = true
        statusMessage = "Refreshing account state..."
        run {
            defer { self.isRefreshInProgress = false }
            self.logService?.debug("refreshing account state")
            let state = try await self.refreshState()
            self.apply(state)
            self.statusMessage = "Refreshed accounts."
            self.logService?.info("refreshed; accounts=\(state.accounts.count), activeID=\(state.activeAccountID?.uuidString ?? "<none>")")
        }
    }

    public func loginNewCodexAccount() {
        guard !isLoginInProgress else { return }
        isLoginInProgress = true
        lastError = nil
        statusMessage = "Opening Codex login..."
        logService?.info("starting Codex ChatGPT OAuth flow")

        run {
            defer { self.isLoginInProgress = false }
            let result = try await self.loginNewAccount { url in
                try await self.openAuthURL(url)
                await MainActor.run {
                    self.statusMessage = "Complete the Codex login in your browser. This will time out after 5 minutes."
                }
            }
            self.apply(result.state)
            self.statusMessage = "Saved new Codex login as \(result.savedAlias). Current Codex auth was not switched."
            self.logService?.info("saved new login alias=\(result.savedAlias) without switching active auth")
        } onFailure: {
            self.isLoginInProgress = false
        }
    }

    public func addCurrentAccount(alias requestedAlias: String?) {
        if let savedAccount = savedAccountForCurrentAuth {
            statusMessage = "Current Codex auth is already saved as \(savedAccount.displayName)."
            return
        }

        logService?.info("adding current live auth (requestedAlias=\(requestedAlias ?? "<auto>"))")
        run {
            let result = try await self.addAccount(
                sourceURL: self.installer.liveAuthFileURL,
                requestedAlias: requestedAlias
            )
            self.apply(result.state)
            self.statusMessage = "Saved current Codex auth as \(result.savedAlias)."
            self.logService?.info("saved current auth as alias=\(result.savedAlias)")
        }
    }

    public func importAccount(from url: URL, alias requestedAlias: String? = nil) {
        logService?.info("importing account from \(url.lastPathComponent) (requestedAlias=\(requestedAlias ?? "<auto>"))")
        run {
            let result = try await self.addAccount(
                sourceURL: url,
                requestedAlias: requestedAlias
            )
            self.apply(result.state)
            self.statusMessage = "Imported account \(result.savedAlias)."
            self.logService?.info("imported alias=\(result.savedAlias) from \(url.lastPathComponent)")
        }
    }

    public func switchTo(_ account: CodexAccount, restartCodexApp: Bool) {
        logService?.info("switching to alias=\(account.alias) (restartCodexApp=\(restartCodexApp))")
        run {
            let result = try await self.switchAccount(
                accountID: account.id,
                restartCodexApp: restartCodexApp
            )
            self.apply(result.state)
            self.statusMessage = self.switchMessage(for: result, restartWasRequested: restartCodexApp)
            self.logService?.info("switch complete alias=\(result.switchedAlias) wasAlreadyActive=\(result.wasAlreadyActive) restartOutcome=\(String(describing: result.restartOutcome))")
        }
    }

    public func remove(_ account: CodexAccount) {
        logService?.info("removing alias=\(account.alias)")
        run {
            let result = try await self.removeAccount(accountID: account.id)
            self.apply(result.state)
            self.statusMessage = result.removedAlias.isEmpty
                ? "Account was already removed."
                : "Removed saved account \(result.removedAlias). Current Codex auth was left untouched."
            self.logService?.info("removed alias=\(result.removedAlias)")
        }
    }

    public func rename(_ account: CodexAccount, to newAlias: String) {
        logService?.info("renaming alias=\(account.alias) -> \(newAlias)")
        run {
            let result = try await self.renameAccount(accountID: account.id, newAlias: newAlias)
            self.apply(result.state)
            self.statusMessage = "Renamed account to \(result.newAlias)."
            self.logService?.info("renamed to alias=\(result.newAlias)")
        }
    }

    public func setRestartCodexAppAfterSwitch(_ enabled: Bool) {
        run {
            let settings = try await self.updateSettings.setRestartCodexAppAfterSwitch(enabled)
            self.apply(settings)
            self.statusMessage = enabled
                ? "Codex App will restart after switching."
                : "Codex App restart after switching disabled."
            self.logService?.info("setting restartCodexAppAfterSwitch=\(enabled)")
        }
    }

    public func setAllowNetworkQuotaAPIs(_ enabled: Bool) {
        run {
            let settings = try await self.updateSettings.setAllowNetworkQuotaAPIs(enabled)
            self.apply(settings)
            self.statusMessage = enabled
                ? "Network quota API calls enabled."
                : "Network quota API calls disabled."
            self.logService?.info("setting allowNetworkQuotaAPIs=\(enabled)")
        }
    }

    public func setPreserveAgentPreferencesPerAccount(_ enabled: Bool) {
        run {
            let settings = try await self.updateSettings.setPreserveAgentPreferencesPerAccount(enabled)
            self.apply(settings)
            self.statusMessage = enabled
                ? "Per-account agent settings will be remembered (requires restart Codex App on switch)."
                : "Per-account agent settings disabled."
            self.logService?.info("setting preserveAgentPreferencesPerAccount=\(enabled)")
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        run {
            try self.launchAtLoginController.setEnabled(enabled)
            let actualValue = self.launchAtLoginController.isEnabled
            let settings = try await self.updateSettings.setLaunchAtLogin(actualValue)
            self.apply(settings)
            self.statusMessage = actualValue ? "Launch at login enabled." : "Launch at login disabled."
            self.logService?.info("setting launchAtLogin=\(actualValue) (requested=\(enabled))")
        } onFailure: {
            var settings = self.settings
            settings.launchAtLogin = self.launchAtLoginController.isEnabled
            self.settings = settings
        }
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: - Live auth watcher

    private func startLiveAuthWatcher() {
        liveAuthWatcher.start { [weak self] in
            Task { @MainActor in
                self?.handleLiveAuthChange()
            }
        }
    }

    private func handleLiveAuthChange() {
        logService?.debug("live auth file changed; syncing active snapshot")
        run {
            let result = try await self.syncLiveAuthUseCase()
            if result.didUpdateSnapshot || result.didReassignActive {
                let state = try await self.refreshState()
                self.apply(state)
                if result.didUpdateSnapshot {
                    self.logService?.info("captured rotated refresh token into snapshot id=\(result.updatedAccountID?.uuidString ?? "<none>")")
                }
                if result.didReassignActive {
                    self.logService?.info("reconciled active account to id=\(result.updatedAccountID?.uuidString ?? "<none>")")
                }
            }
        }
    }

    // MARK: - Logs

    public var logsDirectoryURL: URL {
        if let url = logService?.logsDirectoryURL { return url }
        return URL(fileURLWithPath: storageLocations.logsDirectoryPath, isDirectory: true)
    }

    public var currentLogFileURL: URL {
        if let url = logService?.currentLogFileURL { return url }
        return URL(fileURLWithPath: storageLocations.currentLogFilePath)
    }

    public var isLoggingAvailable: Bool {
        logService != nil
    }

    /// Export the rolling log files (current + retained generations) into the
    /// chosen destination as a single combined text file.
    public func exportLogs(to destination: URL) {
        guard let logService else {
            setError(CodexKeyringError.fileSystemFailure(reason: "Logging is not initialised; nothing to export."))
            return
        }
        statusMessage = "Exporting logs..."
        logService.info("user requested log export to \(destination.lastPathComponent)")
        Task.detached { [weak self] in
            do {
                try logService.exportLogs(to: destination)
                await MainActor.run {
                    self?.statusMessage = "Logs exported to \(destination.path)."
                }
                logService.info("log export complete at \(destination.path)")
            } catch {
                await MainActor.run {
                    self?.setError(error)
                }
                logService.error("log export failed: \(error.localizedDescription)")
            }
        }
    }

    private func run(
        _ operation: @escaping () async throws -> Void,
        onFailure: (() -> Void)? = nil
    ) {
        Task {
            do {
                try await operation()
            } catch {
                onFailure?()
                setError(error)
            }
        }
    }

    private func apply(_ state: AccountState) {
        accounts = state.accounts
        activeAccountID = state.activeAccountID
        currentAuthMetadata = state.currentAuthMetadata
        apply(state.settings)
    }

    private func apply(_ settings: AppSettings) {
        var resolved = settings
        resolved.launchAtLogin = launchAtLoginController.isEnabled
        self.settings = resolved
    }

    private func switchMessage(
        for result: SwitchAccountResult,
        restartWasRequested: Bool
    ) -> String {
        let base: String
        if let restartOutcome = result.restartOutcome {
            base = message(for: restartOutcome)
        } else if result.wasAlreadyActive {
            base = "\(result.switchedAlias) was already the active Codex auth."
        } else if restartWasRequested {
            base = "Switched Codex CLI auth to \(result.switchedAlias)."
        } else {
            base = "Switched Codex CLI auth to \(result.switchedAlias). Restart Codex App if it was already open."
        }
        if result.appliedAgentPreferences {
            return base + " Restored saved agent settings for this account."
        }
        return base
    }

    private func message(for outcome: CodexAppRestartOutcome) -> String {
        switch outcome {
        case .wasNotRunning:
            return "Codex App was not running; Codex CLI will use the switched account immediately."
        case .relaunched:
            return "Codex App was restarted so it can reload the switched auth state."
        case .bundleMissing(let path):
            return "Codex App was quit, but \(path) was not found for relaunch."
        }
    }

    private func setError(_ error: Error) {
        lastError = error.localizedDescription
        statusMessage = error.localizedDescription
        logService?.error("operation failed: \(error.localizedDescription)")
    }

    private func isStableAccountIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty && identifier != "api-key"
    }
}

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

public struct URLAccessScope: Sendable {
    private let stopAccessing: @MainActor @Sendable () -> Void

    public init(stopAccessing: @escaping @MainActor @Sendable () -> Void) {
        self.stopAccessing = stopAccessing
    }

    @MainActor
    func stop() {
        stopAccessing()
    }
}

@MainActor
public final class AccountStore: ObservableObject {
    @Published public private(set) var accounts: [CodexAccount] = []
    @Published public private(set) var activeAccountID: UUID?
    @Published public private(set) var currentAuthMetadata: AuthMetadata?
    @Published public private(set) var isRefreshInProgress = false
    @Published public private(set) var isLoginInProgress = false
    @Published public private(set) var isQuotaRefreshInProgress = false
    @Published public private(set) var isLogExportInProgress = false
    @Published public private(set) var isOperationInProgress = false
    @Published public private(set) var settings = AppSettings()
    @Published public private(set) var quotaStates: [UUID: AccountQuotaState] = [:]
    @Published public var statusMessage: String = "Ready."
    @Published public var lastError: String?

    public let storageLocations: AccountStorageLocations
    public let isLaunchAtLoginSupported: Bool

    private let installer: any CodexAuthInstalling
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let openAuthURL: @Sendable (URL) async throws -> Void
    private let logService: (any AppLogService)?
    private let liveAuthWatcher: any LiveAuthWatching
    private let operationQueue = AccountStoreOperationQueue()

    private let refreshState: RefreshStateUseCase
    private let addAccount: AddAccountUseCase
    private let switchAccount: SwitchAccountUseCase
    private let removeAccount: RemoveAccountUseCase
    private let renameAccount: RenameAccountUseCase
    private let updateSettings: UpdateSettingsUseCase
    private let loginNewAccount: LoginNewAccountUseCase
    private let syncLiveAuthUseCase: SyncLiveAuthUseCase
    private let refreshAccountQuotas: RefreshAccountQuotasUseCase
    private var quotaRefreshTask: Task<Void, Never>?
    private var quotaRefreshConfiguration: QuotaRefreshConfiguration?
    private var queuedOperationCount = 0
    private var isLiveAuthSyncScheduled = false
    private var needsLiveAuthSyncAfterCurrent = false

    public init(
        repository: any AccountRepository,
        installer: any CodexAuthInstalling,
        authReader: any AuthFileReading,
        appController: any CodexAppControlling,
        launchAtLoginController: any LaunchAtLoginControlling,
        loginService: any CodexLoginServicing,
        agentPreferencesPort: any CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort(),
        quotaQuery: any AccountQuotaQuerying = NoopAccountQuotaQuery(),
        storageLocations: AccountStorageLocations,
        openAuthURL: @escaping @Sendable (URL) async throws -> Void,
        logService: (any AppLogService)? = nil,
        liveAuthWatcher: any LiveAuthWatching = NoopLiveAuthWatcher(),
        startupError: Error? = nil
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
        self.refreshAccountQuotas = RefreshAccountQuotasUseCase(
            repository: repository,
            installer: installer,
            query: quotaQuery
        )
        self.settings.launchAtLogin = launchAtLoginController.isEnabled
        logService?.info("AccountStore initialised; launch-at-login supported=\(launchAtLoginController.isSupported)")
        refresh()
        if let startupError {
            setError(startupError)
        }
        startLiveAuthWatcher()
    }

    deinit {
        quotaRefreshTask?.cancel()
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
        return AccountIdentityMatcher.firstMatchingAccount(for: currentAuthMetadata, in: accounts)
    }

    public var canSaveCurrentAuth: Bool {
        currentAuthMetadata != nil && savedAccountForCurrentAuth == nil
    }

    public var canAddCurrentLogin: Bool {
        canSaveCurrentAuth && !isAccountWorkInProgress
    }

    public var canLoginNewAccount: Bool {
        !isAccountWorkInProgress
    }

    public var canImportAccount: Bool {
        !isAccountWorkInProgress
    }

    public var canRefreshAccounts: Bool {
        !isAccountWorkInProgress
    }

    public var canRefreshQuotas: Bool {
        settings.allowNetworkQuotaAPIs
            && !accounts.isEmpty
            && !isAccountWorkInProgress
    }

    public func canSwitch(to account: CodexAccount) -> Bool {
        accounts.contains(where: { $0.id == account.id }) && !isAccountWorkInProgress
    }

    public func canRemove(_ account: CodexAccount) -> Bool {
        accounts.contains(where: { $0.id == account.id }) && !isAccountWorkInProgress
    }

    public func canBeginRename(_ account: CodexAccount) -> Bool {
        accounts.contains(where: { $0.id == account.id }) && !isAccountWorkInProgress
    }

    public func canRename(_ account: CodexAccount, to newAlias: String) -> Bool {
        let cleanedAlias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        return accounts.contains(where: { $0.id == account.id })
            && cleanedAlias != account.alias
            && !isAccountWorkInProgress
    }

    public var canEditPreferences: Bool {
        !isOperationInProgress
    }

    public var canEditQuotaRefreshInterval: Bool {
        settings.allowNetworkQuotaAPIs && canEditPreferences
    }

    public func canSetRestartCodexAppAfterSwitch(to enabled: Bool) -> Bool {
        settings.restartCodexAppAfterSwitch != enabled && canEditPreferences
    }

    public func canSetAllowNetworkQuotaAPIs(to enabled: Bool) -> Bool {
        settings.allowNetworkQuotaAPIs != enabled && canEditPreferences
    }

    public func canSetQuotaRefreshInterval(to minutes: Int) -> Bool {
        let normalizedMinutes = AppSettings.normalizedQuotaRefreshInterval(minutes)
        return settings.quotaRefreshIntervalMinutes != normalizedMinutes
            && canEditQuotaRefreshInterval
    }

    public func canSetPreserveAgentPreferencesPerAccount(to enabled: Bool) -> Bool {
        settings.preserveAgentPreferencesPerAccount != enabled && canEditPreferences
    }

    public func canSetLaunchAtLogin(to enabled: Bool) -> Bool {
        isLaunchAtLoginSupported
            && settings.launchAtLogin != enabled
            && canEditPreferences
    }

    public var canExportLogs: Bool {
        isLoggingAvailable && !isLogExportInProgress
    }

    public var isStatusBusy: Bool {
        isOperationInProgress
            || isRefreshInProgress
            || isLoginInProgress
            || isQuotaRefreshInProgress
            || isLogExportInProgress
    }

    private var isAccountWorkInProgress: Bool {
        isOperationInProgress
            || isRefreshInProgress
            || isLoginInProgress
            || isQuotaRefreshInProgress
    }

    public func refresh() {
        guard canRefreshAccounts else { return }
        isRefreshInProgress = true
        statusMessage = "Refreshing account state..."
        run {
            defer { self.isRefreshInProgress = false }
            self.logService?.debug("refreshing account state")
            let state = try await self.refreshState()
            self.apply(state)
            if self.lastError == nil && !self.isQuotaRefreshInProgress {
                self.statusMessage = "Refreshed accounts."
            }
            self.logService?.info("refreshed; accounts=\(state.accounts.count), activeID=\(state.activeAccountID?.uuidString ?? "<none>")")
        }
    }

    public func loginNewCodexAccount() {
        guard canLoginNewAccount else { return }
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
            var message = "Saved new Codex login as \(result.savedAlias). Current Codex auth was not switched."
            if let cleanupWarningReason = result.cleanupWarningReason {
                message += " Temporary login files could not be cleaned up: \(cleanupWarningReason)"
                self.logService?.warning("login staging cleanup warning: \(cleanupWarningReason)")
            }
            self.statusMessage = message
            self.logService?.info("saved new login alias=\(result.savedAlias) without switching active auth")
        } onFailure: { _ in
            self.isLoginInProgress = false
        }
    }

    public func addCurrentAccount(alias requestedAlias: String?) {
        guard !isAccountWorkInProgress else { return }
        guard currentAuthMetadata != nil else {
            lastError = nil
            statusMessage = "No readable Codex auth.json to save."
            logService?.info("add current auth skipped; live auth is unreadable")
            return
        }

        if let savedAccount = savedAccountForCurrentAuth {
            lastError = nil
            statusMessage = "Current Codex auth is already saved as \(savedAccount.displayName)."
            return
        }

        logService?.info("adding current live auth (requestedAlias=\(requestedAlias ?? "<auto>"))")
        run {
            let result = try await self.addAccount(
                sourceURL: self.installer.liveAuthFileURL,
                requestedAlias: requestedAlias,
                activate: true
            )
            self.apply(result.state)
            self.statusMessage = self.addAccountMessage(
                base: "Saved current Codex auth as \(result.savedAlias).",
                result: result
            )
            self.logService?.info("saved current auth as alias=\(result.savedAlias)")
        }
    }

    public func importAccount(
        from url: URL,
        alias requestedAlias: String? = nil,
        accessScope: URLAccessScope? = nil
    ) {
        guard canImportAccount else {
            accessScope?.stop()
            return
        }
        logService?.info("importing account from \(url.lastPathComponent) (requestedAlias=\(requestedAlias ?? "<auto>"))")
        run {
            defer { accessScope?.stop() }
            let result = try await self.addAccount(
                sourceURL: url,
                requestedAlias: requestedAlias,
                activate: false
            )
            self.apply(result.state)
            self.statusMessage = self.addAccountMessage(
                base: "Imported account \(result.savedAlias). Current Codex auth was not switched.",
                result: result
            )
            self.logService?.info("imported alias=\(result.savedAlias) from \(url.lastPathComponent)")
        }
    }

    public func switchTo(_ account: CodexAccount, restartCodexApp: Bool) {
        guard canSwitch(to: account) else { return }
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
        guard canRemove(account) else { return }
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
        let cleanedAlias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canRename(account, to: cleanedAlias) else { return }
        logService?.info("renaming alias=\(account.alias) -> \(cleanedAlias)")
        run {
            let result = try await self.renameAccount(accountID: account.id, newAlias: cleanedAlias)
            self.apply(result.state)
            if result.didRename {
                let displayName = result.state.accounts.first { $0.id == account.id }?.displayName
                    ?? result.newAlias
                self.statusMessage = result.newAlias.isEmpty
                    ? "Cleared alias. Account will show as \(displayName)."
                    : "Renamed account to \(displayName)."
                self.logService?.info("renamed to alias=\(result.newAlias)")
            } else {
                self.statusMessage = "Account alias is already \(result.newAlias)."
                self.logService?.info("rename skipped; alias already \(result.newAlias)")
            }
        }
    }

    public func setRestartCodexAppAfterSwitch(_ enabled: Bool) {
        guard canSetRestartCodexAppAfterSwitch(to: enabled) else { return }
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
        guard canSetAllowNetworkQuotaAPIs(to: enabled) else { return }
        run {
            let settings = try await self.updateSettings.setAllowNetworkQuotaAPIs(enabled)
            self.apply(settings)
            self.statusMessage = enabled
                ? "Network quota API calls enabled."
                : "Network quota API calls disabled."
            self.logService?.info("setting allowNetworkQuotaAPIs=\(enabled)")
        }
    }

    public func setQuotaRefreshIntervalMinutes(_ minutes: Int) {
        guard canSetQuotaRefreshInterval(to: minutes) else { return }
        run {
            let settings = try await self.updateSettings.setQuotaRefreshIntervalMinutes(minutes)
            self.apply(settings)
            self.statusMessage = "Quota refresh interval set to every \(settings.quotaRefreshIntervalMinutes) minutes."
            self.logService?.info("setting quotaRefreshIntervalMinutes=\(settings.quotaRefreshIntervalMinutes)")
        }
    }

    public func setPreserveAgentPreferencesPerAccount(_ enabled: Bool) {
        guard canSetPreserveAgentPreferencesPerAccount(to: enabled) else { return }
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
        guard canSetLaunchAtLogin(to: enabled) else { return }
        run {
            try self.launchAtLoginController.setEnabled(enabled)
            let actualValue = self.launchAtLoginController.isEnabled
            let settings = try await self.updateSettings.setLaunchAtLogin(actualValue)
            self.apply(settings)
            self.statusMessage = actualValue ? "Launch at login enabled." : "Launch at login disabled."
            self.logService?.info("setting launchAtLogin=\(actualValue) (requested=\(enabled))")
        } onFailure: { _ in
            var settings = self.settings
            settings.launchAtLogin = self.launchAtLoginController.isEnabled
            self.settings = settings
        }
    }

    public func clearError() {
        if let lastError, statusMessage == lastError {
            statusMessage = "Ready."
        }
        lastError = nil
    }

    public func reportUserFacingError(_ error: Error) {
        setError(error)
    }

    // MARK: - Quota

    public func refreshQuotasNow() {
        refreshQuotas(allowDuringAccountWork: false)
    }

    private func refreshQuotas(allowDuringAccountWork: Bool) {
        guard settings.allowNetworkQuotaAPIs else {
            lastError = nil
            quotaStates = [:]
            statusMessage = "Network quota API calls are disabled."
            return
        }
        guard !accounts.isEmpty else {
            lastError = nil
            quotaStates = [:]
            statusMessage = "No saved accounts to refresh quotas for."
            return
        }
        if allowDuringAccountWork {
            guard !isQuotaRefreshInProgress else { return }
        } else {
            guard canRefreshQuotas else { return }
        }

        let preserveExistingError = allowDuringAccountWork && lastError != nil
        isQuotaRefreshInProgress = true
        if !preserveExistingError {
            statusMessage = "Refreshing account quotas..."
        }
        let chatGPTAccountIDs = accounts
            .filter { $0.authMode == "chatgpt" }
            .map(\.id)
        for accountID in chatGPTAccountIDs {
            quotaStates[accountID] = .loading(accountID: accountID)
        }

        run(
            clearErrorOnStart: !preserveExistingError,
            reportErrorOnFailure: !preserveExistingError
        ) {
            defer { self.isQuotaRefreshInProgress = false }
            self.logService?.debug("refreshing account quotas")
            let result = try await self.refreshAccountQuotas()
            self.accounts = result.accounts
            self.quotaStates = result.states
            if !preserveExistingError && self.lastError == nil {
                self.statusMessage = self.quotaRefreshMessage(for: result)
            }
            let successfulCount = result.states.values.filter { $0.phase == .available }.count
            self.logService?.info("quota refresh complete; accounts=\(result.states.count), successful=\(successfulCount)")
        } onFailure: { error in
            self.isQuotaRefreshInProgress = false
            self.markLoadingQuotaStatesFailed(error)
        }
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
        guard !isLiveAuthSyncScheduled else {
            needsLiveAuthSyncAfterCurrent = true
            logService?.debug("live auth file changed while sync is pending; coalescing follow-up")
            return
        }

        isLiveAuthSyncScheduled = true
        logService?.debug("live auth file changed; syncing active snapshot")
        run(clearErrorOnStart: false) {
            defer {
                self.isLiveAuthSyncScheduled = false
                if self.needsLiveAuthSyncAfterCurrent {
                    self.needsLiveAuthSyncAfterCurrent = false
                    self.handleLiveAuthChange()
                }
            }
            let result = try await self.syncLiveAuthUseCase()
            if result.didUpdateSnapshot || result.didUpdateMetadata || result.didReassignActive {
                let state = try await self.refreshState()
                self.apply(state)
                if result.didUpdateSnapshot {
                    self.logService?.info("captured rotated refresh token into snapshot id=\(result.updatedAccountID?.uuidString ?? "<none>")")
                }
                if result.didUpdateMetadata {
                    self.logService?.info("refreshed live auth metadata for account id=\(result.updatedAccountID?.uuidString ?? "<none>")")
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
        guard !isLogExportInProgress else { return }
        lastError = nil
        guard let logService else {
            setError(CodexKeyringError.fileSystemFailure(reason: "Logging is not initialised; nothing to export."))
            return
        }
        isLogExportInProgress = true
        statusMessage = "Exporting logs..."
        logService.info("user requested log export to \(destination.lastPathComponent)")

        Task.detached(priority: .utility) { [weak self] in
            do {
                try logService.exportLogs(to: destination)
                await MainActor.run {
                    self?.isLogExportInProgress = false
                    self?.statusMessage = "Logs exported to \(destination.path)."
                }
                logService.info("log export complete at \(destination.path)")
            } catch {
                await MainActor.run {
                    self?.isLogExportInProgress = false
                    self?.setError(error)
                }
                logService.error("log export failed: \(error.localizedDescription)")
            }
        }
    }

    private func run(
        clearErrorOnStart: Bool = true,
        reportErrorOnFailure: Bool = true,
        _ operation: @escaping @MainActor @Sendable () async throws -> Void,
        onFailure: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        if clearErrorOnStart {
            lastError = nil
        }
        beginQueuedOperation()
        operationQueue.enqueue {
            defer { self.finishQueuedOperation() }
            try await operation()
        } onFailure: { [weak self] error in
            onFailure?(error)
            if reportErrorOnFailure {
                self?.setError(error)
            } else {
                self?.logService?.error("background operation failed: \(error.localizedDescription)")
            }
        }
    }

    private func beginQueuedOperation() {
        queuedOperationCount += 1
        isOperationInProgress = true
    }

    private func finishQueuedOperation() {
        queuedOperationCount = max(0, queuedOperationCount - 1)
        isOperationInProgress = queuedOperationCount > 0
    }

    private func apply(_ state: AccountState) {
        accounts = state.accounts
        activeAccountID = state.activeAccountID
        currentAuthMetadata = state.currentAuthMetadata
        pruneQuotaStates()
        apply(state.settings)
    }

    private func apply(_ settings: AppSettings) {
        var resolved = settings
        resolved.launchAtLogin = launchAtLoginController.isEnabled
        self.settings = resolved
        configureQuotaRefresh(current: resolved)
    }

    private func switchMessage(
        for result: SwitchAccountResult,
        restartWasRequested: Bool
    ) -> String {
        let base: String
        if let restartFailureReason = result.restartFailureReason {
            let switchedPrefix = result.wasAlreadyActive
                ? "\(result.switchedAlias) was already the active Codex auth"
                : "Switched Codex CLI auth to \(result.switchedAlias)"
            base = "\(switchedPrefix), but Codex App could not be restarted: \(restartFailureReason)"
        } else if let restartOutcome = result.restartOutcome {
            base = message(for: restartOutcome)
        } else if result.wasAlreadyActive {
            base = "\(result.switchedAlias) was already the active Codex auth."
        } else if restartWasRequested {
            base = "Switched Codex CLI auth to \(result.switchedAlias)."
        } else {
            base = "Switched Codex CLI auth to \(result.switchedAlias). Restart Codex App if it was already open."
        }
        var message = base
        if result.appliedAgentPreferences {
            message += " Restored saved agent settings for this account."
        }
        if let warning = result.agentPreferencesWarningReason {
            message += " Agent settings could not be fully updated: \(warning)"
        }
        if let warning = result.projectArrangementWarningReason {
            message += " Codex project list layout could not be preserved: \(warning)"
        }
        return message
    }

    private func addAccountMessage(
        base: String,
        result: AddAccountResult
    ) -> String {
        var message = base
        if let warning = result.agentPreferencesWarningReason {
            message += " Agent settings were not saved for this account: \(warning)"
        }
        return message
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

    private func pruneQuotaStates() {
        let accountIDs = Set(accounts.map(\.id))
        quotaStates = quotaStates.filter { accountIDs.contains($0.key) }
    }

    private func markLoadingQuotaStatesFailed(_ error: Error) {
        let message = error.localizedDescription
        let updatedAt = Date()
        quotaStates = quotaStates.mapValues { state in
            guard state.phase == .loading else { return state }
            return .error(
                accountID: state.accountID,
                message: message,
                updatedAt: updatedAt
            )
        }
    }

    private func quotaRefreshMessage(for result: RefreshAccountQuotasResult) -> String {
        let states = Array(result.states.values)
        let successfulCount = states.filter { $0.phase == .available }.count
        let errorCount = states.filter { $0.phase == .error }.count

        if successfulCount > 0 {
            var message = "Refreshed quota for \(successfulCount) account\(successfulCount == 1 ? "" : "s")."
            if errorCount > 0 {
                message += " \(errorCount) account\(errorCount == 1 ? "" : "s") need attention."
            }
            return message
        }

        if errorCount > 0 {
            return "Quota refresh finished; \(errorCount) account\(errorCount == 1 ? "" : "s") need attention."
        }

        let hasOAuthAccount = result.accounts.contains { $0.authMode == "chatgpt" }
        if !hasOAuthAccount && !result.accounts.isEmpty {
            return "No ChatGPT/Codex OAuth accounts expose quota."
        }

        return "No readable quota data was returned."
    }

    private func configureQuotaRefresh(current: AppSettings) {
        if !current.allowNetworkQuotaAPIs {
            quotaStates = [:]
        }

        let wasAutoRefreshEnabled = quotaRefreshConfiguration?.enabled == true
        let previousAccountIDs = quotaRefreshConfiguration?.accountIDs ?? []
        let currentAccountIDs = Set(accounts.map(\.id))
        let configuration = QuotaRefreshConfiguration(
            enabled: current.allowNetworkQuotaAPIs && !currentAccountIDs.isEmpty,
            intervalMinutes: current.quotaRefreshIntervalMinutes,
            accountIDs: currentAccountIDs
        )
        guard quotaRefreshConfiguration != configuration else { return }

        quotaRefreshConfiguration = configuration
        quotaRefreshTask?.cancel()
        quotaRefreshTask = nil

        guard configuration.enabled else { return }

        quotaRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let seconds = UInt64(max(1, configuration.intervalMinutes) * 60)
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                if Task.isCancelled { break }
                self?.refreshQuotasNow()
            }
        }

        let addedAccountIDs = currentAccountIDs.subtracting(previousAccountIDs)
        if !wasAutoRefreshEnabled || !addedAccountIDs.isEmpty {
            refreshQuotas(allowDuringAccountWork: true)
        }
    }
}

private struct QuotaRefreshConfiguration: Equatable {
    var enabled: Bool
    var intervalMinutes: Int
    var accountIDs: Set<UUID>
}

import Foundation
import CodexKeyringDomain

@MainActor
public final class AccountStore: ObservableObject {
    @Published public internal(set) var accounts: [CodexAccount] = []
    @Published public internal(set) var activeAccountID: UUID?
    @Published public internal(set) var currentAuthMetadata: AuthMetadata?
    @Published public internal(set) var isRefreshInProgress = false
    @Published public internal(set) var isLoginInProgress = false
    @Published public internal(set) var isQuotaRefreshInProgress = false
    @Published public internal(set) var isLogExportInProgress = false
    @Published public internal(set) var isOperationInProgress = false
    @Published public internal(set) var settings = AppSettings()
    @Published public internal(set) var quotaStates: [UUID: AccountQuotaState] = [:]
    @Published public var statusMessage: String = "Ready."
    @Published public var lastError: String?

    public let storageLocations: AccountStorageLocations
    public let isLaunchAtLoginSupported: Bool

    let installer: any CodexAuthInstalling
    let launchAtLoginController: any LaunchAtLoginControlling
    let openAuthURL: @Sendable (URL) async throws -> Void
    let logService: (any AppLogService)?
    let liveAuthWatcher: any LiveAuthWatching
    let operationLock: any CodexKeyringOperationLocking
    let operationQueue = AccountStoreOperationQueue()

    let useCases: AccountStoreUseCases
    let quotaRefreshScheduler = AccountQuotaRefreshScheduler()
    var liveAuthSyncCoalescer = AccountLiveAuthSyncCoalescer()
    var queuedOperationCount = 0
    var loginOperationTask: Task<Void, Never>?
    var loginCancellationRequested = false

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
        operationLock: any CodexKeyringOperationLocking = NoopCodexKeyringOperationLock(),
        startupError: Error? = nil
    ) {
        self.installer = installer
        self.launchAtLoginController = launchAtLoginController
        self.storageLocations = storageLocations
        self.openAuthURL = openAuthURL
        self.logService = logService
        self.liveAuthWatcher = liveAuthWatcher
        self.operationLock = operationLock
        self.isLaunchAtLoginSupported = launchAtLoginController.isSupported
        self.useCases = AccountStoreUseCases(
            repository: repository,
            installer: installer,
            authReader: authReader,
            appController: appController,
            loginService: loginService,
            agentPreferencesPort: agentPreferencesPort,
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
        loginOperationTask?.cancel()
        liveAuthWatcher.stop()
    }
}

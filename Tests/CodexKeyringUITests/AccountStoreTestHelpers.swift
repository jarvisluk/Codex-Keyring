import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
func makeStore(
    repository: BlockingAccountRepository,
    authReader: any AuthFileReading = MissingAuthReader(),
    liveAuthWatcher: any LiveAuthWatching = NoopLiveAuthWatcher(),
    loginService: any CodexLoginServicing = NoopLoginService(),
    installer: any CodexAuthInstalling = NoopInstaller(),
    logService: (any AppLogService)? = nil,
    launchAtLoginController: any LaunchAtLoginControlling = NoopLaunchAtLoginController(),
    appController: any CodexAppControlling = NoopAppController(),
    agentPreferencesPort: any CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort(),
    startupError: Error? = nil
) -> AccountStore {
    AccountStore(
        repository: repository,
        installer: installer,
        authReader: authReader,
        appController: appController,
        launchAtLoginController: launchAtLoginController,
        loginService: loginService,
        agentPreferencesPort: agentPreferencesPort,
        storageLocations: AccountStorageLocations(
            codexAuthPath: "/tmp/auth.json",
            applicationSupportPath: "/tmp/CodexKeyring",
            accountsDirectoryPath: "/tmp/CodexKeyring/Accounts",
            backupsDirectoryPath: "/tmp/CodexKeyring/Backups",
            logsDirectoryPath: "/tmp/CodexKeyring/Logs",
            currentLogFilePath: "/tmp/CodexKeyring/Logs/current.log"
        ),
        openAuthURL: { _ in },
        logService: logService,
        liveAuthWatcher: liveAuthWatcher,
        startupError: startupError
    )
}

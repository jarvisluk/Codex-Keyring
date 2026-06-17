import AppKit
import CodexKeyringDomain
import CodexKeyringInfrastructure
import CodexKeyringUI

enum AccountStoreFactory {
    @MainActor
    static func makeStore() -> AccountStore {
        let startupError: Error?
        do {
            try AppPaths.ensureDirectories()
            startupError = nil
        } catch {
            startupError = CodexKeyringError.fileSystemFailure(
                reason: "Could not prepare Codex Keyring storage directories: \(error.localizedDescription)"
            )
        }
        CodexKeyringLog.bootstrapFileSink()
        let appLogger = CodexKeyringLog.makeAppLogger(.app)
        appLogger.info("Codex Keyring launching; logFile=\(AppPaths.currentLogFile.path)")
        if let startupError {
            appLogger.error("startup storage preparation failed: \(startupError.localizedDescription)")
        }

        let repository = FileSystemManifestRepository()
        let installer = LiveCodexAuthInstaller()
        let authReader = AuthFileParser()
        let agentPreferencesPort = LiveCodexAgentPreferencesPort()
        return AccountStore(
            repository: repository,
            installer: installer,
            authReader: authReader,
            appController: NSWorkspaceCodexAppController(),
            launchAtLoginController: SMAppServiceLaunchAtLogin(),
            loginService: ChatGPTOAuthLoginService(),
            agentPreferencesPort: agentPreferencesPort,
            quotaQuery: ChatGPTQuotaClient(),
            storageLocations: AccountStorageLocations(
                codexAuthPath: AppPaths.codexAuthFile.path,
                applicationSupportPath: AppPaths.applicationSupportDirectory.path,
                accountsDirectoryPath: AppPaths.accountsDirectory.path,
                backupsDirectoryPath: AppPaths.backupsDirectory.path,
                logsDirectoryPath: AppPaths.logsDirectory.path,
                currentLogFilePath: AppPaths.currentLogFile.path
            ),
            openAuthURL: { url in
                try await MainActor.run {
                    guard NSWorkspace.shared.open(url) else {
                        throw CodexKeyringError.codexLoginFailed(reason: "Could not open browser for Codex login.")
                    }
                }
            },
            logService: CodexKeyringLog.makeAppLogger(.store),
            liveAuthWatcher: LiveAuthFileWatcher(),
            operationLock: FileSystemCodexKeyringOperationLock(),
            startupError: startupError
        )
    }
}

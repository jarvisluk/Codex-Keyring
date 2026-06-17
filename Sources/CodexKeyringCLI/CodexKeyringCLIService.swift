import CodexKeyringDomain
import CodexKeyringInfrastructure
import Foundation

struct CodexKeyringCLIService: Sendable {
    var repository: any AccountRepository
    var installer: any CodexAuthInstalling
    var authReader: any AuthFileReading
    var appController: any CodexAppControlling
    var preferencesPort: any CodexAgentPreferencesPorting
    var quotaQuery: any AccountQuotaQuerying
    var operationLock: any CodexKeyringOperationLocking

    static func live() -> CodexKeyringCLIService {
        CodexKeyringLog.bootstrapFileSink()
        return CodexKeyringCLIService(
            repository: FileSystemManifestRepository(),
            installer: LiveCodexAuthInstaller(),
            authReader: AuthFileParser(),
            appController: NSWorkspaceCodexAppController(),
            preferencesPort: LiveCodexAgentPreferencesPort(),
            quotaQuery: ChatGPTQuotaClient(),
            operationLock: FileSystemCodexKeyringOperationLock()
        )
    }

    func prepareStorage() throws {
        try AppPaths.ensureDirectories()
    }

    func loadStateReadOnly() async throws -> AccountState {
        let manifest = try await repository.load()
        let currentAuth = try await readLiveAuthIfPresent()
        return AccountState(manifest: manifest, currentAuthMetadata: currentAuth)
    }

    func saveCurrent(alias: String?) async throws -> AddAccountResult {
        try await operationLock.withLock {
            try await AddAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: authReader,
                preferencesPort: preferencesPort
            )(
                sourceURL: installer.liveAuthFileURL,
                requestedAlias: alias,
                activate: true
            )
        }
    }

    func importAuth(path: String, alias: String?) async throws -> AddAccountResult {
        try await operationLock.withLock {
            try await AddAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: authReader,
                preferencesPort: preferencesPort
            )(
                sourceURL: URL(fileURLWithPath: path),
                requestedAlias: alias,
                activate: false
            )
        }
    }

    func switchAccount(
        selector: String,
        restart: CodexKeyringCLICommand.RestartPreference
    ) async throws -> SwitchAccountResult {
        try await operationLock.withLock {
            let state = try await loadStateReadOnly()
            let account = try AccountSelector().resolve(selector, accounts: state.accounts)
            let restartCodexApp = switch restart {
            case .settingsDefault:
                state.settings.restartCodexAppAfterSwitch
            case .restart:
                true
            case .noRestart:
                false
            }

            return try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: authReader,
                appController: appController,
                preferencesPort: preferencesPort
            )(
                accountID: account.id,
                restartCodexApp: restartCodexApp
            )
        }
    }

    func renameAccount(selector: String, alias: String) async throws -> RenameAccountResult {
        try await operationLock.withLock {
            let state = try await loadStateReadOnly()
            let account = try AccountSelector().resolve(selector, accounts: state.accounts)
            return try await RenameAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: authReader
            )(
                accountID: account.id,
                newAlias: alias
            )
        }
    }

    func removeAccount(selector: String) async throws -> RemoveAccountResult {
        try await operationLock.withLock {
            let state = try await loadStateReadOnly()
            let account = try AccountSelector().resolve(selector, accounts: state.accounts)
            return try await RemoveAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: authReader
            )(
                accountID: account.id
            )
        }
    }

    func updateSetting(key: String, value: String) async throws -> AppSettings {
        try await operationLock.withLock {
            let update = UpdateSettingsUseCase(repository: repository)
            switch key {
            case "restartCodexAppAfterSwitch", "restart-after-switch":
                return try await update.setRestartCodexAppAfterSwitch(try parseBool(value))
            case "allowNetworkQuotaAPIs", "allow-network-quota-apis":
                return try await update.setAllowNetworkQuotaAPIs(try parseBool(value))
            case "quotaRefreshIntervalMinutes", "quota-refresh-interval-minutes":
                guard let minutes = Int(value) else {
                    throw CodexKeyringCLIExecutionError.invalidValue(
                        "quotaRefreshIntervalMinutes must be one of 5, 15, or 30."
                    )
                }
                guard AppSettings.quotaRefreshIntervalOptions.contains(minutes) else {
                    throw CodexKeyringCLIExecutionError.invalidValue(
                        "quotaRefreshIntervalMinutes must be one of 5, 15, or 30."
                    )
                }
                return try await update.setQuotaRefreshIntervalMinutes(minutes)
            case "preserveAgentPreferencesPerAccount", "preserve-agent-preferences":
                return try await update.setPreserveAgentPreferencesPerAccount(try parseBool(value))
            default:
                throw CodexKeyringCLIExecutionError.invalidValue(
                    "Unknown setting '\(key)'. Supported settings: restartCodexAppAfterSwitch, allowNetworkQuotaAPIs, quotaRefreshIntervalMinutes, preserveAgentPreferencesPerAccount."
                )
            }
        }
    }

    func refreshQuotas() async throws -> RefreshAccountQuotasResult {
        try await operationLock.withLock {
            try await RefreshAccountQuotasUseCase(
                repository: repository,
                installer: installer,
                query: quotaQuery
            )()
        }
    }

    func pathsDTO() -> CLIPathsDTO {
        CLIPathsDTO(
            codexAuthPath: AppPaths.codexAuthFile.path,
            codexConfigPath: AppPaths.codexConfigTomlFile.path,
            codexGlobalStatePath: AppPaths.codexGlobalStateFile.path,
            applicationSupportPath: AppPaths.applicationSupportDirectory.path,
            manifestPath: AppPaths.manifestFile.path,
            accountsDirectoryPath: AppPaths.accountsDirectory.path,
            backupsDirectoryPath: AppPaths.backupsDirectory.path,
            logsDirectoryPath: AppPaths.logsDirectory.path,
            currentLogFilePath: AppPaths.currentLogFile.path,
            operationLockPath: AppPaths.operationLockFile.path
        )
    }

    private func readLiveAuthIfPresent() async throws -> AuthMetadata? {
        do {
            return try await authReader.read(from: installer.liveAuthFileURL)
        } catch CodexKeyringError.authFileMissing {
            return nil
        }
    }

    private func parseBool(_ rawValue: String) throws -> Bool {
        switch rawValue.lowercased() {
        case "true", "yes", "1", "on", "enabled":
            return true
        case "false", "no", "0", "off", "disabled":
            return false
        default:
            throw CodexKeyringCLIExecutionError.invalidValue(
                "Expected a boolean value: true, false, yes, no, 1, 0, on, or off."
            )
        }
    }
}

enum CodexKeyringCLIExecutionError: LocalizedError, Equatable {
    case invalidValue(String)
    case confirmationRequired(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return message
        case .confirmationRequired(let message):
            return message
        }
    }
}

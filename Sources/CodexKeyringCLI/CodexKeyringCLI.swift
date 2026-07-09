import CodexKeyringDomain
import Foundation

public struct CodexKeyringCLIIO: Sendable {
    public var writeOutput: @Sendable (String) -> Void
    public var writeError: @Sendable (String) -> Void

    public init(
        writeOutput: @escaping @Sendable (String) -> Void,
        writeError: @escaping @Sendable (String) -> Void
    ) {
        self.writeOutput = writeOutput
        self.writeError = writeError
    }

    public static let standard = CodexKeyringCLIIO(
        writeOutput: { print($0) },
        writeError: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    )
}

public struct CodexKeyringCLI: Sendable {
    private var service: CodexKeyringCLIService
    private var io: CodexKeyringCLIIO
    private var parser = CodexKeyringCLIParser()

    public init(io: CodexKeyringCLIIO = .standard) {
        self.service = .live()
        self.io = io
    }

    init(
        service: CodexKeyringCLIService,
        io: CodexKeyringCLIIO = .standard
    ) {
        self.service = service
        self.io = io
    }

    @discardableResult
    public func run(arguments: [String]) async -> Int32 {
        do {
            let command = try parser.parse(arguments)
            if case .help = command {
                try await execute(command)
                return 0
            }
            try service.prepareStorage()
            try await execute(command)
            return 0
        } catch let error as CodexKeyringCLIParseError {
            io.writeError(error.localizedDescription)
            io.writeError("")
            io.writeError(Self.helpText)
            return 2
        } catch {
            io.writeError(error.localizedDescription)
            return 1
        }
    }

    private func execute(_ command: CodexKeyringCLICommand) async throws {
        switch command {
        case .help:
            io.writeOutput(Self.helpText)
        case .list(let json):
            let state = try await service.loadStateReadOnly()
            if json {
                try writeJSON(state.accounts.map { CLIAccountDTO(account: $0, active: state.activeAccount?.id == $0.id) })
            } else {
                io.writeOutput(CLIFormat.accountList(state))
            }
        case .status(let json):
            let state = try await service.loadStateReadOnly()
            if json {
                try writeJSON(
                    CLIStatusDTO(
                        accountCount: state.accounts.count,
                        activeAccount: state.activeAccount.map {
                            CLIAccountDTO(account: $0, active: true)
                        },
                        currentAuth: state.currentAuthMetadata.map(CLIAuthMetadataDTO.init),
                        settings: CLISettingsDTO(settings: state.settings)
                    )
                )
            } else {
                io.writeOutput(CLIFormat.status(state))
            }
        case .paths(let json):
            let paths = service.pathsDTO()
            if json {
                try writeJSON(paths)
            } else {
                io.writeOutput(CLIFormat.paths(paths))
            }
        case .saveCurrent(let alias, let json):
            let result = try await service.saveCurrent(alias: alias)
            try writeMutation(
                message: "Saved current Codex auth as \(result.savedAlias).",
                state: result.state,
                alias: result.savedAlias,
                json: json
            )
        case .importAuth(let path, let alias, let json):
            let result = try await service.importAuth(path: path, alias: alias)
            try writeMutation(
                message: "Imported account \(result.savedAlias). Current Codex auth was not switched.",
                state: result.state,
                alias: result.savedAlias,
                json: json
            )
        case .switchAccount(let selector, let restart, let json):
            let result = try await service.switchAccount(selector: selector, restart: restart)
            var message = result.wasAlreadyActive
                ? "\(result.switchedAlias) was already active."
                : "Switched to \(result.switchedAlias)."
            if let restartOutcome = result.restartOutcome {
                message += " Restart: \(restartOutcome.cliDescription)."
            }
            try writeMutation(
                message: message,
                state: result.state,
                alias: result.switchedAlias,
                json: json
            )
            if let warning = result.agentPreferencesWarningReason {
                io.writeError("Warning: \(warning)")
            }
            if let warning = result.projectArrangementWarningReason {
                io.writeError("Warning: \(warning)")
            }
            if let failure = result.restartFailureReason {
                io.writeError("Warning: \(failure)")
            }
        case .rename(let selector, let alias, let json):
            let result = try await service.renameAccount(selector: selector, alias: alias)
            try writeMutation(
                message: result.didRename ? "Renamed account to \(result.newAlias)." : "Account was already named \(result.newAlias).",
                state: result.state,
                alias: result.newAlias,
                json: json
            )
        case .remove(let selector, let confirmed, let json):
            guard confirmed else {
                throw CodexKeyringCLIExecutionError.confirmationRequired(
                    "Removing a saved account requires --yes. This deletes only the Codex Keyring snapshot, not the OpenAI account."
                )
            }
            let result = try await service.removeAccount(selector: selector)
            if json {
                try writeJSON(
                    CLIMutationDTO(
                        ok: true,
                        message: "Removed account \(result.removedAlias).",
                        account: nil
                    )
                )
            } else {
                io.writeOutput("Removed account \(result.removedAlias).")
            }
        case .settingsGet(let json):
            let state = try await service.loadStateReadOnly()
            if json {
                try writeJSON(CLISettingsDTO(settings: state.settings))
            } else {
                io.writeOutput(CLIFormat.settings(state.settings))
            }
        case .settingsSet(let key, let value, let json):
            let settings = try await service.updateSetting(key: key, value: value)
            if json {
                try writeJSON(CLISettingsDTO(settings: settings))
            } else {
                io.writeOutput(CLIFormat.settings(settings))
            }
        case .quotaRefresh(let json):
            let before = try await service.loadStateReadOnly()
            let result = try await service.refreshQuotas()
            if json {
                try writeJSON(CLIFormat.quotaDTO(result, enabled: before.settings.allowNetworkQuotaAPIs))
            } else {
                io.writeOutput(CLIFormat.quota(result, enabled: before.settings.allowNetworkQuotaAPIs))
            }
        }
    }

    private func writeMutation(
        message: String,
        state: AccountState,
        alias: String,
        json: Bool
    ) throws {
        let account = state.accounts.first { $0.displayName == alias || $0.alias == alias }
        if json {
            try writeJSON(
                CLIMutationDTO(
                    ok: true,
                    message: message,
                    account: account.map {
                        CLIAccountDTO(account: $0, active: state.activeAccount?.id == $0.id)
                    }
                )
            )
        } else {
            io.writeOutput(message)
        }
    }

    private func writeJSON<T: Encodable>(_ value: T) throws {
        io.writeOutput(try CLIFormat.json(value))
    }

    static let helpText = """
    usage: ckr <command> [options]

    Commands:
      list [--json]                         List saved accounts.
      status [--json]                       Show active account and current auth.
      paths [--json]                        Show Codex Keyring storage paths.
      save-current [--alias <name>]         Save the current ~/.codex/auth.json.
      import <auth.json> [--alias <name>]   Import an auth snapshot without switching.
      switch <account> [--restart|--no-restart]
                                             Switch live Codex auth to an account.
      rename <account> <new-alias>          Rename a saved account.
      remove <account> --yes                Remove a saved account snapshot.
      quota refresh [--json]                Refresh usage limits if enabled.
      settings get [--json]                 Show CLI-manageable settings.
      settings set <key> <value>            Update a CLI-manageable setting.

    Account selectors:
      Use a UUID, UUID prefix, exact alias, exact email, account identifier, or fingerprint prefix.

    Settings:
      restartCodexAppAfterSwitch true|false
      showDockIcon true|false
      allowNetworkQuotaAPIs true|false
      quotaRefreshIntervalMinutes 5|15|30
      preserveAgentPreferencesPerAccount true|false
    """
}

private extension CodexAppRestartOutcome {
    var cliDescription: String {
        switch self {
        case .wasNotRunning:
            return "Codex App was not running"
        case .relaunched:
            return "Codex App relaunched"
        case .bundleMissing(let path):
            return "Codex App bundle missing at \(path)"
        }
    }
}

import CodexKeyringDomain
import Foundation

struct CLIAccountDTO: Codable, Equatable {
    var id: String
    var alias: String
    var email: String
    var plan: String
    var authMode: String
    var fingerprint: String
    var tokenExpiresAt: String?
    var active: Bool

    init(account: CodexAccount, active: Bool) {
        self.id = account.id.uuidString
        self.alias = account.displayName
        self.email = account.displayEmail
        self.plan = account.plan
        self.authMode = account.authMode
        self.fingerprint = account.shortFingerprint
        self.tokenExpiresAt = CLIFormat.isoString(account.tokenExpiresAt)
        self.active = active
    }
}

struct CLIAuthMetadataDTO: Codable, Equatable {
    var email: String
    var plan: String
    var authMode: String
    var fingerprint: String
    var tokenExpiresAt: String?

    init(metadata: AuthMetadata) {
        self.email = metadata.email
        self.plan = metadata.plan
        self.authMode = metadata.authMode
        self.fingerprint = String(metadata.fingerprint.prefix(10))
        self.tokenExpiresAt = CLIFormat.isoString(metadata.tokenExpiresAt)
    }
}

struct CLIStatusDTO: Codable, Equatable {
    var accountCount: Int
    var activeAccount: CLIAccountDTO?
    var currentAuth: CLIAuthMetadataDTO?
    var settings: CLISettingsDTO
}

struct CLISettingsDTO: Codable, Equatable {
    var restartCodexAppAfterSwitch: Bool
    var showDockIcon: Bool
    var allowNetworkQuotaAPIs: Bool
    var quotaRefreshIntervalMinutes: Int
    var preserveAgentPreferencesPerAccount: Bool

    init(settings: AppSettings) {
        self.restartCodexAppAfterSwitch = settings.restartCodexAppAfterSwitch
        self.showDockIcon = settings.showDockIcon
        self.allowNetworkQuotaAPIs = settings.allowNetworkQuotaAPIs
        self.quotaRefreshIntervalMinutes = settings.quotaRefreshIntervalMinutes
        self.preserveAgentPreferencesPerAccount = settings.preserveAgentPreferencesPerAccount
    }
}

struct CLIPathsDTO: Codable, Equatable {
    var codexAuthPath: String
    var codexConfigPath: String
    var codexGlobalStatePath: String
    var applicationSupportPath: String
    var manifestPath: String
    var accountsDirectoryPath: String
    var backupsDirectoryPath: String
    var logsDirectoryPath: String
    var currentLogFilePath: String
    var operationLockPath: String
}

struct CLIMutationDTO: Codable, Equatable {
    var ok: Bool
    var message: String
    var account: CLIAccountDTO?
}

struct CLIQuotaAccountDTO: Codable, Equatable {
    var id: String
    var alias: String
    var email: String
    var phase: String
    var health: String
    var message: String?
    var updatedAt: String?
    var primaryBucket: CLIQuotaBucketDTO?
}

struct CLIQuotaBucketDTO: Codable, Equatable {
    var name: String
    var remainingPercent: Double?
    var unlimited: Bool
    var creditsBalance: String?
    var resetsAt: String?
}

struct CLIQuotaRefreshDTO: Codable, Equatable {
    var enabled: Bool
    var accounts: [CLIQuotaAccountDTO]
}

enum CLIFormat {
    static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(data: try encoder.encode(value), encoding: .utf8) ?? "{}"
    }

    static func accountList(_ state: AccountState) -> String {
        guard !state.accounts.isEmpty else {
            return "No saved Codex accounts."
        }

        let rows = state.accounts.map { account in
            [
                account.activeMarker(in: state),
                account.id.uuidString.prefixString(8),
                account.displayName,
                account.displayEmail,
                account.plan,
                account.authMode,
                account.shortFingerprint
            ]
        }
        return table(
            headers: ["", "ID", "Alias", "Email", "Plan", "Auth", "Fingerprint"],
            rows: rows
        )
    }

    static func status(_ state: AccountState) -> String {
        var lines: [String] = []
        lines.append("Codex Keyring")
        lines.append("Accounts: \(state.accounts.count)")
        if let active = state.activeAccount {
            lines.append("Active: \(active.displayName) <\(active.displayEmail)> (\(active.id.uuidString.prefixString(8)))")
        } else {
            lines.append("Active: none")
        }
        if let metadata = state.currentAuthMetadata {
            let expires = isoString(metadata.tokenExpiresAt) ?? "unknown"
            lines.append("Current auth: \(metadata.email) (\(metadata.authMode), \(metadata.plan), expires \(expires))")
        } else {
            lines.append("Current auth: not found")
        }
        lines.append("Restart after switch: \(state.settings.restartCodexAppAfterSwitch)")
        lines.append("Dock icon: \(state.settings.showDockIcon ? "shown" : "hidden")")
        lines.append("Quota APIs: \(state.settings.allowNetworkQuotaAPIs ? "enabled" : "disabled")")
        lines.append("Quota refresh interval: \(state.settings.quotaRefreshIntervalMinutes)m")
        lines.append("Preserve agent preferences: \(state.settings.preserveAgentPreferencesPerAccount)")
        return lines.joined(separator: "\n")
    }

    static func settings(_ settings: AppSettings) -> String {
        [
            "restartCodexAppAfterSwitch: \(settings.restartCodexAppAfterSwitch)",
            "showDockIcon: \(settings.showDockIcon)",
            "allowNetworkQuotaAPIs: \(settings.allowNetworkQuotaAPIs)",
            "quotaRefreshIntervalMinutes: \(settings.quotaRefreshIntervalMinutes)",
            "preserveAgentPreferencesPerAccount: \(settings.preserveAgentPreferencesPerAccount)"
        ].joined(separator: "\n")
    }

    static func paths(_ paths: CLIPathsDTO) -> String {
        [
            "codexAuthPath: \(paths.codexAuthPath)",
            "codexConfigPath: \(paths.codexConfigPath)",
            "codexGlobalStatePath: \(paths.codexGlobalStatePath)",
            "applicationSupportPath: \(paths.applicationSupportPath)",
            "manifestPath: \(paths.manifestPath)",
            "accountsDirectoryPath: \(paths.accountsDirectoryPath)",
            "backupsDirectoryPath: \(paths.backupsDirectoryPath)",
            "logsDirectoryPath: \(paths.logsDirectoryPath)",
            "currentLogFilePath: \(paths.currentLogFilePath)",
            "operationLockPath: \(paths.operationLockPath)"
        ].joined(separator: "\n")
    }

    static func quota(_ result: RefreshAccountQuotasResult, enabled: Bool) -> String {
        guard enabled else {
            return "Quota APIs are disabled. Enable them with: ckr settings set allowNetworkQuotaAPIs true"
        }

        guard !result.accounts.isEmpty else {
            return "No saved Codex accounts."
        }

        let rows = result.accounts.map { account in
            let state = result.states[account.id]
            let bucket = state?.snapshot?.primaryBucket
            let remaining = bucket?.remainingPercent.map { "\(Int($0.rounded()))%" }
                ?? (bucket?.isUnlimited == true ? "unlimited" : "-")
            return [
                account.id.uuidString.prefixString(8),
                account.displayName,
                account.displayEmail,
                state?.phase.rawValue ?? "idle",
                state?.health.rawValue ?? "unsupported",
                remaining
            ]
        }
        return table(
            headers: ["ID", "Alias", "Email", "Phase", "Health", "Remaining"],
            rows: rows
        )
    }

    static func quotaDTO(_ result: RefreshAccountQuotasResult, enabled: Bool) -> CLIQuotaRefreshDTO {
        CLIQuotaRefreshDTO(
            enabled: enabled,
            accounts: result.accounts.map { account in
                let state = result.states[account.id]
                let bucket = state?.snapshot?.primaryBucket
                return CLIQuotaAccountDTO(
                    id: account.id.uuidString,
                    alias: account.displayName,
                    email: account.displayEmail,
                    phase: state?.phase.rawValue ?? "idle",
                    health: state?.health.rawValue ?? "unsupported",
                    message: state?.message,
                    updatedAt: isoString(state?.updatedAt),
                    primaryBucket: bucket.map {
                        CLIQuotaBucketDTO(
                            name: $0.displayName,
                            remainingPercent: $0.remainingPercent,
                            unlimited: $0.isUnlimited,
                            creditsBalance: $0.credits?.balance,
                            resetsAt: isoString($0.windows.compactMap(\.resetsAt).min())
                        )
                    }
                )
            }
        )
    }

    static func isoString(_ date: Date?) -> String? {
        guard let date else { return nil }
        return ISO8601DateFormatter().string(from: date)
    }

    private static func table(headers: [String], rows: [[String]]) -> String {
        let widths = headers.indices.map { index in
            max(
                headers[index].count,
                rows.map { $0[index].count }.max() ?? 0
            )
        }
        let header = row(headers, widths: widths)
        let divider = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")
        let body = rows.map { row($0, widths: widths) }.joined(separator: "\n")
        return [header, divider, body].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func row(_ columns: [String], widths: [Int]) -> String {
        columns.enumerated()
            .map { index, value in value.padding(toLength: widths[index], withPad: " ", startingAt: 0) }
            .joined(separator: "  ")
    }
}

private extension CodexAccount {
    func activeMarker(in state: AccountState) -> String {
        state.activeAccount?.id == id ? "*" : ""
    }
}

private extension StringProtocol {
    func prefixString(_ maxLength: Int) -> String {
        String(prefix(maxLength))
    }
}

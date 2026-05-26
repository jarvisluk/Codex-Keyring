import Foundation

public struct AccountManifest: Codable, Sendable {
    public var accounts: [CodexAccount]
    public var activeAccountID: UUID?
    public var settings: AppSettings

    public init(
        accounts: [CodexAccount],
        activeAccountID: UUID?,
        settings: AppSettings
    ) {
        self.accounts = accounts
        self.activeAccountID = activeAccountID
        self.settings = settings
    }

    public static let empty = AccountManifest(
        accounts: [],
        activeAccountID: nil,
        settings: AppSettings()
    )
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var restartCodexAppAfterSwitch: Bool
    public var launchAtLogin: Bool
    public var allowNetworkQuotaAPIs: Bool
    public var quotaRefreshIntervalMinutes: Int
    /// When true, the switch flow captures the current Codex agent preferences
    /// (model, reasoning effort, approval/sandbox, Codex App agent mode) into
    /// the currently active account before switching, and applies the target
    /// account's stored preferences afterwards. Requires Codex App to be
    /// restarted as part of the switch — otherwise the running Codex App will
    /// overwrite the changes on its next quit.
    public var preserveAgentPreferencesPerAccount: Bool

    public init(
        restartCodexAppAfterSwitch: Bool = true,
        launchAtLogin: Bool = false,
        allowNetworkQuotaAPIs: Bool = false,
        quotaRefreshIntervalMinutes: Int = 15,
        preserveAgentPreferencesPerAccount: Bool = true
    ) {
        self.restartCodexAppAfterSwitch = restartCodexAppAfterSwitch
        self.launchAtLogin = launchAtLogin
        self.allowNetworkQuotaAPIs = allowNetworkQuotaAPIs
        self.quotaRefreshIntervalMinutes = Self.normalizedQuotaRefreshInterval(quotaRefreshIntervalMinutes)
        self.preserveAgentPreferencesPerAccount = preserveAgentPreferencesPerAccount
    }

    enum CodingKeys: String, CodingKey {
        case restartCodexAppAfterSwitch
        case launchAtLogin
        case allowNetworkQuotaAPIs
        case quotaRefreshIntervalMinutes
        case preserveAgentPreferencesPerAccount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Default to true so a plain "Switch" always restarts Codex App; legacy
        // manifests that omit the key inherit the new default.
        self.restartCodexAppAfterSwitch = try container.decodeIfPresent(Bool.self, forKey: .restartCodexAppAfterSwitch) ?? true
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.allowNetworkQuotaAPIs = try container.decodeIfPresent(Bool.self, forKey: .allowNetworkQuotaAPIs) ?? false
        self.quotaRefreshIntervalMinutes = Self.normalizedQuotaRefreshInterval(
            try container.decodeIfPresent(Int.self, forKey: .quotaRefreshIntervalMinutes) ?? 15
        )
        // Default to true so a fresh install and any legacy manifest both
        // inherit the new "remember per-account agent settings" behavior.
        self.preserveAgentPreferencesPerAccount = try container.decodeIfPresent(Bool.self, forKey: .preserveAgentPreferencesPerAccount) ?? true
    }

    public static func normalizedQuotaRefreshInterval(_ minutes: Int) -> Int {
        [5, 15, 30].contains(minutes) ? minutes : 15
    }
}

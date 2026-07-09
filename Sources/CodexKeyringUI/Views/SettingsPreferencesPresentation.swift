import CodexKeyringDomain

struct SettingsPreferencesPresentation: Equatable {
    let restartCodexAppNote: String
    let agentPreferencesNote: String
    let canToggleLaunchAtLogin: Bool
    let canToggleShowDockIcon: Bool
    let canToggleRestartCodexAppAfterSwitch: Bool
    let canTogglePreserveAgentPreferencesPerAccount: Bool
    let quotaAPI: SettingsQuotaAPIPresentation

    init(
        restartCodexAppAfterSwitch: Bool,
        quotaRefreshIntervalMinutes: Int,
        canToggleLaunchAtLogin: Bool = false,
        canToggleShowDockIcon: Bool = false,
        canToggleRestartCodexAppAfterSwitch: Bool = false,
        canTogglePreserveAgentPreferencesPerAccount: Bool = false,
        canToggleAllowNetworkQuotaAPIs: Bool = false,
        canEditQuotaRefreshInterval: Bool = false
    ) {
        self.canToggleLaunchAtLogin = canToggleLaunchAtLogin
        self.canToggleShowDockIcon = canToggleShowDockIcon
        self.canToggleRestartCodexAppAfterSwitch = canToggleRestartCodexAppAfterSwitch
        self.canTogglePreserveAgentPreferencesPerAccount = canTogglePreserveAgentPreferencesPerAccount
        restartCodexAppNote = "Leave this on when you want Codex App to reload auth immediately. Per-account agent settings are restored only during a restart."
        if restartCodexAppAfterSwitch {
            agentPreferencesNote = "When switching accounts, Codex Keyring restarts Codex App, captures the outgoing account's model, reasoning effort, approval/sandbox mode, and Full Access / Auto Review setting, and applies the incoming account's saved values while Codex App is stopped."
        } else {
            agentPreferencesNote = "Per-account agent settings require Restart Codex App after switching accounts. Turn that on before switching when you want saved model, reasoning effort, approval/sandbox mode, and Full Access / Auto Review settings restored automatically."
        }
        quotaAPI = SettingsQuotaAPIPresentation(
            quotaRefreshIntervalMinutes: quotaRefreshIntervalMinutes,
            canToggleAllowNetworkQuotaAPIs: canToggleAllowNetworkQuotaAPIs,
            canEditQuotaRefreshInterval: canEditQuotaRefreshInterval
        )
    }
}

struct SettingsQuotaAPIPresentation: Equatable {
    let canToggleAllowNetworkQuotaAPIs: Bool
    let canEditQuotaRefreshInterval: Bool
    let intervalOptions: [SettingsQuotaRefreshIntervalOption]
    let quotaRefreshNote: String

    init(
        quotaRefreshIntervalMinutes: Int,
        canToggleAllowNetworkQuotaAPIs: Bool = false,
        canEditQuotaRefreshInterval: Bool = false
    ) {
        self.canToggleAllowNetworkQuotaAPIs = canToggleAllowNetworkQuotaAPIs
        self.canEditQuotaRefreshInterval = canEditQuotaRefreshInterval
        intervalOptions = AppSettings.quotaRefreshIntervalOptions.map(SettingsQuotaRefreshIntervalOption.init)
        quotaRefreshNote = "When enabled, Codex Keyring checks saved ChatGPT/Codex accounts every \(quotaRefreshIntervalMinutes) minutes and refreshes rotated OAuth tokens back into their local snapshots."
    }
}

struct SettingsQuotaRefreshIntervalOption: Equatable, Identifiable {
    let minutes: Int

    var id: Int {
        minutes
    }

    var title: String {
        "\(minutes) minutes"
    }
}

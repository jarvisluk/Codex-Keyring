extension AccountStoreStatusMessages {
    static func restartCodexAppAfterSwitch(enabled: Bool) -> String {
        enabled
            ? "Codex App will restart after switching."
            : "Codex App restart after switching disabled."
    }

    static func allowNetworkQuotaAPIs(enabled: Bool) -> String {
        enabled
            ? "Network quota API calls enabled."
            : "Network quota API calls disabled."
    }

    static func quotaRefreshInterval(minutes: Int) -> String {
        "Quota refresh interval set to every \(minutes) minutes."
    }

    static func preserveAgentPreferencesPerAccount(enabled: Bool) -> String {
        enabled
            ? "Per-account agent settings will be remembered (requires restart Codex App on switch)."
            : "Per-account agent settings disabled."
    }

    static func launchAtLogin(enabled: Bool) -> String {
        enabled ? "Launch at login enabled." : "Launch at login disabled."
    }

    static func showDockIcon(enabled: Bool) -> String {
        enabled ? "Dock icon enabled." : "Dock icon hidden."
    }
}

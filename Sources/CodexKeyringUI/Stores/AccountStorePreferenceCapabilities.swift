import CodexKeyringDomain

extension AccountStoreCapabilities {
    var canEditPreferences: Bool {
        !isOperationInProgress
    }

    var canEditQuotaRefreshInterval: Bool {
        settings.allowNetworkQuotaAPIs && canEditPreferences
    }

    func canSetRestartCodexAppAfterSwitch(to enabled: Bool) -> Bool {
        settings.restartCodexAppAfterSwitch != enabled && canEditPreferences
    }

    func canSetAllowNetworkQuotaAPIs(to enabled: Bool) -> Bool {
        settings.allowNetworkQuotaAPIs != enabled && canEditPreferences
    }

    func canSetQuotaRefreshInterval(to minutes: Int) -> Bool {
        let normalizedMinutes = AppSettings.normalizedQuotaRefreshInterval(minutes)
        return settings.quotaRefreshIntervalMinutes != normalizedMinutes
            && canEditQuotaRefreshInterval
    }

    func canSetPreserveAgentPreferencesPerAccount(to enabled: Bool) -> Bool {
        settings.preserveAgentPreferencesPerAccount != enabled && canEditPreferences
    }

    func canSetLaunchAtLogin(to enabled: Bool) -> Bool {
        isLaunchAtLoginSupported
            && settings.launchAtLogin != enabled
            && canEditPreferences
    }
}

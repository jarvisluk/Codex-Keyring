import CodexKeyringDomain

extension AccountStore {
    public func setRestartCodexAppAfterSwitch(_ enabled: Bool) {
        guard canSetRestartCodexAppAfterSwitch(to: enabled) else { return }
        runPersistedSettingsUpdate(
            statusMessage: { _ in AccountStoreStatusMessages.restartCodexAppAfterSwitch(enabled: enabled) },
            logMessage: { _ in "setting restartCodexAppAfterSwitch=\(enabled)" }
        ) {
            try await self.useCases.updateSettings.setRestartCodexAppAfterSwitch(enabled)
        }
    }

    public func setAllowNetworkQuotaAPIs(_ enabled: Bool) {
        guard canSetAllowNetworkQuotaAPIs(to: enabled) else { return }
        runPersistedSettingsUpdate(
            statusMessage: { _ in AccountStoreStatusMessages.allowNetworkQuotaAPIs(enabled: enabled) },
            logMessage: { _ in "setting allowNetworkQuotaAPIs=\(enabled)" }
        ) {
            try await self.useCases.updateSettings.setAllowNetworkQuotaAPIs(enabled)
        }
    }

    public func setQuotaRefreshIntervalMinutes(_ minutes: Int) {
        guard canSetQuotaRefreshInterval(to: minutes) else { return }
        runPersistedSettingsUpdate(
            statusMessage: { settings in
                AccountStoreStatusMessages.quotaRefreshInterval(minutes: settings.quotaRefreshIntervalMinutes)
            },
            logMessage: { settings in
                "setting quotaRefreshIntervalMinutes=\(settings.quotaRefreshIntervalMinutes)"
            }
        ) {
            try await self.useCases.updateSettings.setQuotaRefreshIntervalMinutes(minutes)
        }
    }

    public func setPreserveAgentPreferencesPerAccount(_ enabled: Bool) {
        guard canSetPreserveAgentPreferencesPerAccount(to: enabled) else { return }
        runPersistedSettingsUpdate(
            statusMessage: { _ in AccountStoreStatusMessages.preserveAgentPreferencesPerAccount(enabled: enabled) },
            logMessage: { _ in "setting preserveAgentPreferencesPerAccount=\(enabled)" }
        ) {
            try await self.useCases.updateSettings.setPreserveAgentPreferencesPerAccount(enabled)
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        guard canSetLaunchAtLogin(to: enabled) else { return }
        runPersistedSettingsUpdate(
            statusMessage: { settings in
                AccountStoreStatusMessages.launchAtLogin(enabled: settings.launchAtLogin)
            },
            logMessage: { settings in
                "setting launchAtLogin=\(settings.launchAtLogin) (requested=\(enabled))"
            },
            onFailure: { _ in
                var settings = self.settings
                settings.launchAtLogin = self.launchAtLoginController.isEnabled
                self.settings = settings
            }
        ) {
            try self.launchAtLoginController.setEnabled(enabled)
            let actualValue = self.launchAtLoginController.isEnabled
            return try await self.useCases.updateSettings.setLaunchAtLogin(actualValue)
        }
    }

}

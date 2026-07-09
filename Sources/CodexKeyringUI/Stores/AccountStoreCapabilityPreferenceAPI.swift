extension AccountStore {
    public var canEditPreferences: Bool {
        capabilities.canEditPreferences
    }

    public var canEditQuotaRefreshInterval: Bool {
        capabilities.canEditQuotaRefreshInterval
    }

    public func canSetRestartCodexAppAfterSwitch(to enabled: Bool) -> Bool {
        capabilities.canSetRestartCodexAppAfterSwitch(to: enabled)
    }

    public func canSetAllowNetworkQuotaAPIs(to enabled: Bool) -> Bool {
        capabilities.canSetAllowNetworkQuotaAPIs(to: enabled)
    }

    public func canSetQuotaRefreshInterval(to minutes: Int) -> Bool {
        capabilities.canSetQuotaRefreshInterval(to: minutes)
    }

    public func canSetPreserveAgentPreferencesPerAccount(to enabled: Bool) -> Bool {
        capabilities.canSetPreserveAgentPreferencesPerAccount(to: enabled)
    }

    public func canSetLaunchAtLogin(to enabled: Bool) -> Bool {
        capabilities.canSetLaunchAtLogin(to: enabled)
    }

    public func canSetShowDockIcon(to enabled: Bool) -> Bool {
        capabilities.canSetShowDockIcon(to: enabled)
    }
}

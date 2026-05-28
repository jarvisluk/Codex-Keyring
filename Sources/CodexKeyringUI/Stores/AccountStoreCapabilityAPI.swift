import CodexKeyringDomain

extension AccountStore {
    var capabilities: AccountStoreCapabilities {
        AccountStoreCapabilities(
            accounts: accounts,
            settings: settings,
            currentAuthMetadata: currentAuthMetadata,
            savedAccountForCurrentAuth: savedAccountForCurrentAuth,
            isLaunchAtLoginSupported: isLaunchAtLoginSupported,
            isLoggingAvailable: isLoggingAvailable,
            isRefreshInProgress: isRefreshInProgress,
            isLoginInProgress: isLoginInProgress,
            isQuotaRefreshInProgress: isQuotaRefreshInProgress,
            isLogExportInProgress: isLogExportInProgress,
            isOperationInProgress: isOperationInProgress
        )
    }
}

extension AccountStoreCapabilities {
    var canExportLogs: Bool {
        isLoggingAvailable && !isLogExportInProgress
    }

    var isStatusBusy: Bool {
        isOperationInProgress
            || isRefreshInProgress
            || isLoginInProgress
            || isQuotaRefreshInProgress
            || isLogExportInProgress
    }

    var isAccountWorkInProgress: Bool {
        isOperationInProgress
            || isRefreshInProgress
            || isLoginInProgress
            || isQuotaRefreshInProgress
    }
}

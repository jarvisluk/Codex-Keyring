extension AccountStore {
    public var canExportLogs: Bool {
        capabilities.canExportLogs
    }

    public var isStatusBusy: Bool {
        capabilities.isStatusBusy
    }

    var isAccountWorkInProgress: Bool {
        capabilities.isAccountWorkInProgress
    }
}

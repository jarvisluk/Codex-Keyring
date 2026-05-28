struct ContentToolbarPresentation: Equatable {
    let addLoginSystemImage: String
    let canAddLogin: Bool
    let canImport: Bool
    let canRefresh: Bool
    let isRefreshLoading: Bool

    init(
        isSettingsPresented: Bool,
        isLoginInProgress: Bool,
        isRefreshInProgress: Bool,
        canLoginNewAccount: Bool,
        canImportAccount: Bool,
        canRefreshAccounts: Bool
    ) {
        addLoginSystemImage = isLoginInProgress ? "hourglass" : "plus.circle"
        canAddLogin = canLoginNewAccount && !isSettingsPresented
        canImport = canImportAccount && !isSettingsPresented
        canRefresh = canRefreshAccounts && !isSettingsPresented
        isRefreshLoading = isRefreshInProgress
    }
}

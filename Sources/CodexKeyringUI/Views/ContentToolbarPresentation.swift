struct ContentToolbarPresentation: Equatable {
    let addLoginTitle: String
    let addLoginSystemImage: String
    let addLoginCancelsInProgress: Bool
    let canAddLogin: Bool
    let canImport: Bool
    let canRefresh: Bool
    let isRefreshLoading: Bool

    init(
        isLoginInProgress: Bool,
        isRefreshInProgress: Bool,
        canLoginNewAccount: Bool,
        canImportAccount: Bool,
        canRefreshAccounts: Bool
    ) {
        addLoginTitle = isLoginInProgress ? "Cancel Login" : "Add Login"
        addLoginSystemImage = isLoginInProgress ? "xmark.circle" : "plus.circle"
        addLoginCancelsInProgress = isLoginInProgress
        canAddLogin = isLoginInProgress || canLoginNewAccount
        canImport = canImportAccount
        canRefresh = canRefreshAccounts
        isRefreshLoading = isRefreshInProgress
    }
}

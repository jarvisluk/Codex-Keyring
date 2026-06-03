struct EmptyAccountsPresentation: Equatable {
    let showsSaveCurrentLogin: Bool
    let canSaveCurrentLogin: Bool
    let canAddLogin: Bool
    let addLoginTitle: String
    let addLoginSystemImage: String
    let addLoginCancelsInProgress: Bool
    let usesProminentAddLoginButton: Bool
    let canImport: Bool

    init(
        canSaveCurrentAuth: Bool,
        canAddCurrentLogin: Bool,
        isLoginInProgress: Bool,
        canLoginNewAccount: Bool,
        canImportAccount: Bool
    ) {
        self.showsSaveCurrentLogin = canSaveCurrentAuth
        self.canSaveCurrentLogin = canAddCurrentLogin
        self.canAddLogin = isLoginInProgress || canLoginNewAccount
        self.addLoginTitle = isLoginInProgress ? "Cancel Login" : "Add Login"
        self.addLoginSystemImage = isLoginInProgress ? "xmark.circle" : "person.badge.plus"
        self.addLoginCancelsInProgress = isLoginInProgress
        self.usesProminentAddLoginButton = !canSaveCurrentAuth
        self.canImport = canImportAccount
    }
}

struct EmptyAccountsPresentation: Equatable {
    let showsSaveCurrentLogin: Bool
    let canSaveCurrentLogin: Bool
    let canAddLogin: Bool
    let addLoginSystemImage: String
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
        self.canAddLogin = canLoginNewAccount
        self.addLoginSystemImage = isLoginInProgress ? "hourglass" : "person.badge.plus"
        self.usesProminentAddLoginButton = !canSaveCurrentAuth
        self.canImport = canImportAccount
    }
}

import CodexKeyringDomain

extension AccountStore {
    public var activeAccount: CodexAccount? {
        AccountState(
            accounts: accounts,
            activeAccountID: activeAccountID,
            settings: settings,
            currentAuthMetadata: currentAuthMetadata
        ).activeAccount
    }

    public var savedAccountForCurrentAuth: CodexAccount? {
        guard let currentAuthMetadata else { return nil }
        return AccountIdentityMatcher.firstMatchingAccount(for: currentAuthMetadata, in: accounts)
    }
}

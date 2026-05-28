import CodexKeyringDomain

extension AccountStore {
    public var canSaveCurrentAuth: Bool {
        capabilities.canSaveCurrentAuth
    }

    public var canAddCurrentLogin: Bool {
        capabilities.canAddCurrentLogin
    }

    public var canLoginNewAccount: Bool {
        capabilities.canLoginNewAccount
    }

    public var canImportAccount: Bool {
        capabilities.canImportAccount
    }

    public var canRefreshAccounts: Bool {
        capabilities.canRefreshAccounts
    }

    public var canRefreshQuotas: Bool {
        capabilities.canRefreshQuotas
    }

    public func canSwitch(to account: CodexAccount) -> Bool {
        capabilities.canSwitch(to: account)
    }

    public func canRemove(_ account: CodexAccount) -> Bool {
        capabilities.canRemove(account)
    }

    public func canBeginRename(_ account: CodexAccount) -> Bool {
        capabilities.canBeginRename(account)
    }

    public func canRename(_ account: CodexAccount, to newAlias: String) -> Bool {
        capabilities.canRename(account, to: newAlias)
    }
}

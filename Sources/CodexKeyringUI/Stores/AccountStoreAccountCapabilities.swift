import Foundation
import CodexKeyringDomain

extension AccountStoreCapabilities {
    var canSaveCurrentAuth: Bool {
        currentAuthMetadata != nil && savedAccountForCurrentAuth == nil
    }

    var canAddCurrentLogin: Bool {
        canSaveCurrentAuth && !isAccountWorkInProgress
    }

    var canLoginNewAccount: Bool {
        !isAccountWorkInProgress
    }

    var canImportAccount: Bool {
        !isAccountWorkInProgress
    }

    var canRefreshAccounts: Bool {
        !isAccountWorkInProgress
    }

    var canRefreshQuotas: Bool {
        settings.allowNetworkQuotaAPIs
            && !accounts.isEmpty
            && !isAccountWorkInProgress
    }

    func canSwitch(to account: CodexAccount) -> Bool {
        contains(account) && !isAccountWorkInProgress
    }

    func canRemove(_ account: CodexAccount) -> Bool {
        contains(account) && !isAccountWorkInProgress
    }

    func canBeginRename(_ account: CodexAccount) -> Bool {
        contains(account) && !isAccountWorkInProgress
    }

    func canRename(_ account: CodexAccount, to newAlias: String) -> Bool {
        let cleanedAlias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        return contains(account)
            && cleanedAlias != account.alias
            && !isAccountWorkInProgress
    }

    private func contains(_ account: CodexAccount) -> Bool {
        accounts.contains { $0.id == account.id }
    }
}

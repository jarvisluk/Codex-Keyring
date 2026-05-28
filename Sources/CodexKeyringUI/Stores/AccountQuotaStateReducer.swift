import Foundation
import CodexKeyringDomain

enum AccountQuotaStateReducer {
    static func pruning(
        _ states: [UUID: AccountQuotaState],
        keepingAccounts accounts: [CodexAccount]
    ) -> [UUID: AccountQuotaState] {
        let accountIDs = Set(accounts.map(\.id))
        return states.filter { accountIDs.contains($0.key) }
    }

    static func markingChatGPTAccountsLoading(
        _ states: [UUID: AccountQuotaState],
        accounts: [CodexAccount]
    ) -> [UUID: AccountQuotaState] {
        var updated = states
        for account in accounts where account.authMode == "chatgpt" {
            updated[account.id] = .loading(accountID: account.id)
        }
        return updated
    }

    static func markingLoadingStatesFailed(
        _ states: [UUID: AccountQuotaState],
        message: String,
        updatedAt: Date
    ) -> [UUID: AccountQuotaState] {
        states.mapValues { state in
            guard state.phase == .loading else { return state }
            return .error(
                accountID: state.accountID,
                message: message,
                updatedAt: updatedAt
            )
        }
    }
}

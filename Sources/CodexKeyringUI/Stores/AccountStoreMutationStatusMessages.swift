import Foundation
import CodexKeyringDomain

extension AccountStoreStatusMessages {
    static func removeAccount(result: RemoveAccountResult) -> String {
        result.removedAlias.isEmpty
            ? "Account was already removed."
            : "Removed saved account \(result.removedAlias). Current Codex auth was left untouched."
    }

    static func renameAccount(result: RenameAccountResult, accountID: UUID) -> String {
        if result.didRename {
            let displayName = result.state.accounts.first { $0.id == accountID }?.displayName
                ?? result.newAlias
            return result.newAlias.isEmpty
                ? "Cleared alias. Account will show as \(displayName)."
                : "Renamed account to \(displayName)."
        }
        return "Account alias is already \(result.newAlias)."
    }
}

import Foundation
import CodexKeyringDomain

extension AccountStore {
    public func remove(_ account: CodexAccount) {
        guard canRemove(account) else { return }
        logService?.info("removing alias=\(account.alias)")
        run {
            let result = try await self.useCases.removeAccount(accountID: account.id)
            self.apply(result.state)
            self.statusMessage = AccountStoreStatusMessages.removeAccount(result: result)
            self.logService?.info("removed alias=\(result.removedAlias)")
        }
    }

    public func rename(_ account: CodexAccount, to newAlias: String) {
        let cleanedAlias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canRename(account, to: cleanedAlias) else { return }
        logService?.info("renaming alias=\(account.alias) -> \(cleanedAlias)")
        run {
            let result = try await self.useCases.renameAccount(accountID: account.id, newAlias: cleanedAlias)
            self.apply(result.state)
            self.statusMessage = AccountStoreStatusMessages.renameAccount(
                result: result,
                accountID: account.id
            )
            if result.didRename {
                self.logService?.info("renamed to alias=\(result.newAlias)")
            } else {
                self.logService?.info("rename skipped; alias already \(result.newAlias)")
            }
        }
    }
}

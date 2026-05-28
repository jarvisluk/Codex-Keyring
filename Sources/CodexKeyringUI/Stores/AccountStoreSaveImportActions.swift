import Foundation
import CodexKeyringDomain

extension AccountStore {
    public func addCurrentAccount(alias requestedAlias: String?) {
        guard !isAccountWorkInProgress else { return }
        guard currentAuthMetadata != nil else {
            lastError = nil
            statusMessage = "No readable Codex auth.json to save."
            logService?.info("add current auth skipped; live auth is unreadable")
            return
        }

        if let savedAccount = savedAccountForCurrentAuth {
            lastError = nil
            statusMessage = AccountStoreStatusMessages.currentAuthAlreadySaved(
                displayName: savedAccount.displayName
            )
            return
        }

        logService?.info("adding current live auth (requestedAlias=\(requestedAlias ?? "<auto>"))")
        run {
            let result = try await self.useCases.addAccount(
                sourceURL: self.installer.liveAuthFileURL,
                requestedAlias: requestedAlias,
                activate: true
            )
            self.apply(result.state)
            self.statusMessage = AccountStoreStatusMessages.addAccount(
                base: "Saved current Codex auth as \(result.savedAlias).",
                result: result
            )
            self.logService?.info("saved current auth as alias=\(result.savedAlias)")
        }
    }

    public func importAccount(
        from url: URL,
        alias requestedAlias: String? = nil,
        accessScope: URLAccessScope? = nil
    ) {
        guard canImportAccount else {
            accessScope?.stop()
            return
        }
        logService?.info("importing account from \(url.lastPathComponent) (requestedAlias=\(requestedAlias ?? "<auto>"))")
        run {
            defer { accessScope?.stop() }
            let result = try await self.useCases.addAccount(
                sourceURL: url,
                requestedAlias: requestedAlias,
                activate: false
            )
            self.apply(result.state)
            self.statusMessage = AccountStoreStatusMessages.addAccount(
                base: "Imported account \(result.savedAlias). Current Codex auth was not switched.",
                result: result
            )
            self.logService?.info("imported alias=\(result.savedAlias) from \(url.lastPathComponent)")
        }
    }
}

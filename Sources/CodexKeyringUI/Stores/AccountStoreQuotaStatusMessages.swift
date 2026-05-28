import CodexKeyringDomain

extension AccountStoreStatusMessages {
    static func quotaRefresh(result: RefreshAccountQuotasResult) -> String {
        let states = Array(result.states.values)
        let successfulCount = states.filter { $0.phase == .available }.count
        let errorCount = states.filter { $0.phase == .error }.count

        if successfulCount > 0 {
            var message = "Refreshed quota for \(successfulCount) account\(successfulCount == 1 ? "" : "s")."
            if errorCount > 0 {
                message += " \(errorCount) account\(errorCount == 1 ? "" : "s") need attention."
            }
            return message
        }

        if errorCount > 0 {
            return "Quota refresh finished; \(errorCount) account\(errorCount == 1 ? "" : "s") need attention."
        }

        let hasOAuthAccount = result.accounts.contains { $0.authMode == "chatgpt" }
        if !hasOAuthAccount && !result.accounts.isEmpty {
            return "No ChatGPT/Codex OAuth accounts expose quota."
        }

        return "No readable quota data was returned."
    }
}

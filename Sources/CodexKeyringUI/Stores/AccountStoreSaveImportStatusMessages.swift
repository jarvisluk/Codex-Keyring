import CodexKeyringDomain

extension AccountStoreStatusMessages {
    static func addAccount(base: String, result: AddAccountResult) -> String {
        var message = base
        if let warning = result.agentPreferencesWarningReason {
            message += " Agent settings were not saved for this account: \(warning)"
        }
        return message
    }

    static func currentAuthAlreadySaved(displayName: String) -> String {
        "Current Codex auth is already saved as \(displayName)."
    }
}

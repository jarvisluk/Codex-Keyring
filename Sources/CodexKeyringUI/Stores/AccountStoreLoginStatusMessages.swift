extension AccountStoreStatusMessages {
    static func loginSuccess(savedAlias: String, cleanupWarningReason: String?) -> String {
        var message = "Saved new Codex login as \(savedAlias). Current Codex auth was not switched."
        if let cleanupWarningReason {
            message += " Temporary login files could not be cleaned up: \(cleanupWarningReason)"
        }
        return message
    }
}

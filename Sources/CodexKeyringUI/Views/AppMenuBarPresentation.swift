import CodexKeyringDomain

public struct AppMenuBarPresentation: Equatable {
    public let isActive: Bool
    public let statusLabel: String

    public init(activeAccount: CodexAccount?, showsSensitiveValues: Bool = false) {
        if let activeAccount {
            self.isActive = true
            let displayName = AccountSensitiveText.displayName(
                for: activeAccount,
                revealed: showsSensitiveValues
            )
            self.statusLabel = "Codex Keyring: \(displayName) active"
        } else {
            self.isActive = false
            self.statusLabel = "Codex Keyring: no active saved account"
        }
    }
}

import CodexKeyringDomain

public struct AppMenuBarPresentation: Equatable {
    public let isActive: Bool
    public let statusLabel: String

    public init(activeAccount: CodexAccount?) {
        if let activeAccount {
            self.isActive = true
            self.statusLabel = "Codex Keyring: \(activeAccount.displayName) active"
        } else {
            self.isActive = false
            self.statusLabel = "Codex Keyring: no active saved account"
        }
    }
}

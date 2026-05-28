import CodexKeyringDomain

public struct AppMenuBarPresentation: Equatable {
    public let systemImage: String
    public let statusLabel: String

    public init(activeAccount: CodexAccount?) {
        if let activeAccount {
            self.systemImage = "person.crop.circle.badge.checkmark"
            self.statusLabel = "Codex Keyring: \(activeAccount.displayName) active"
        } else {
            self.systemImage = "person.crop.circle.badge.questionmark"
            self.statusLabel = "Codex Keyring: no active saved account"
        }
    }
}

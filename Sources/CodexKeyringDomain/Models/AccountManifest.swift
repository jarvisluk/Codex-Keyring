import Foundation

public struct AccountManifest: Codable, Sendable {
    public var accounts: [CodexAccount]
    public var activeAccountID: UUID?
    public var settings: AppSettings

    public init(
        accounts: [CodexAccount],
        activeAccountID: UUID?,
        settings: AppSettings
    ) {
        self.accounts = accounts
        self.activeAccountID = activeAccountID
        self.settings = settings
    }

    public static let empty = AccountManifest(
        accounts: [],
        activeAccountID: nil,
        settings: AppSettings()
    )
}

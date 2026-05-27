import Foundation

public struct AccountState: Equatable, Sendable {
    public var accounts: [CodexAccount]
    public var activeAccountID: UUID?
    public var settings: AppSettings
    public var currentAuthMetadata: AuthMetadata?

    public init(
        accounts: [CodexAccount] = [],
        activeAccountID: UUID? = nil,
        settings: AppSettings = AppSettings(),
        currentAuthMetadata: AuthMetadata? = nil
    ) {
        self.accounts = accounts
        self.activeAccountID = activeAccountID
        self.settings = settings
        self.currentAuthMetadata = currentAuthMetadata
    }

    public static let empty = AccountState()

    public var activeAccount: CodexAccount? {
        if let id = activeAccountID,
           let account = accounts.first(where: { $0.id == id }) {
            return account
        }
        if let currentAuthMetadata {
            return AccountIdentityMatcher.firstMatchingAccount(for: currentAuthMetadata, in: accounts)
        }
        return nil
    }

    public func toManifest() -> AccountManifest {
        AccountManifest(accounts: accounts, activeAccountID: activeAccountID, settings: settings)
    }
}

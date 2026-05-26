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

public struct AppSettings: Codable, Equatable, Sendable {
    public var restartCodexAppAfterSwitch: Bool
    public var launchAtLogin: Bool
    public var allowNetworkQuotaAPIs: Bool

    public init(
        restartCodexAppAfterSwitch: Bool = false,
        launchAtLogin: Bool = false,
        allowNetworkQuotaAPIs: Bool = false
    ) {
        self.restartCodexAppAfterSwitch = restartCodexAppAfterSwitch
        self.launchAtLogin = launchAtLogin
        self.allowNetworkQuotaAPIs = allowNetworkQuotaAPIs
    }
}

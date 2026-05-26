import Foundation

struct AccountManifest: Codable {
    var accounts: [CodexAccount]
    var activeAccountID: UUID?
    var settings: AppSettings

    static let empty = AccountManifest(
        accounts: [],
        activeAccountID: nil,
        settings: AppSettings()
    )
}

struct AppSettings: Codable, Equatable {
    var restartCodexAppAfterSwitch: Bool = false
    var launchAtLogin: Bool = false
    var allowNetworkQuotaAPIs: Bool = false
}

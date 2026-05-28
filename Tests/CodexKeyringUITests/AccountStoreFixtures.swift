import Foundation
@testable import CodexKeyringDomain

func makeAccount(id: UUID, alias: String = "person", email: String? = nil) -> CodexAccount {
    CodexAccount(
        id: id,
        alias: alias,
        email: email ?? "\(alias)@example.com",
        plan: "plus",
        authMode: "chatgpt",
        accountIdentifier: "\(alias)-account",
        snapshotFileName: "\(alias).auth.json",
        fingerprint: "\(alias)-fingerprint",
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        tokenExpiresAt: nil
    )
}

func quotaEnabledSettings() -> AppSettings {
    AppSettings(allowNetworkQuotaAPIs: true)
}

func makeAccountManifest(
    accounts: [CodexAccount] = [],
    activeAccountID: UUID? = nil,
    settings: AppSettings = AppSettings()
) -> AccountManifest {
    AccountManifest(
        accounts: accounts,
        activeAccountID: activeAccountID ?? accounts.first?.id,
        settings: settings
    )
}

func makeQuotaEnabledRepository(
    accounts: [CodexAccount] = [],
    activeAccountID: UUID? = nil,
    snapshotExists: Bool = true
) -> BlockingAccountRepository {
    BlockingAccountRepository(
        manifest: makeAccountManifest(
            accounts: accounts,
            activeAccountID: activeAccountID,
            settings: quotaEnabledSettings()
        ),
        snapshotExists: snapshotExists
    )
}

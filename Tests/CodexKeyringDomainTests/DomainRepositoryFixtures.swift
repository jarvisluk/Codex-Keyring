import Foundation
@testable import CodexKeyringDomain

func accountRepository(
    accounts: [CodexAccount] = [],
    activeAccountID: UUID? = nil,
    settings: AppSettings = AppSettings(),
    saveError: Error? = nil,
    saveErrorsByAttempt: [Int: Error] = [:],
    writeError: Error? = nil,
    deleteError: Error? = nil,
    snapshotExists: Bool = true
) -> InMemoryAccountRepository {
    InMemoryAccountRepository(
        manifest: AccountManifest(
            accounts: accounts,
            activeAccountID: activeAccountID,
            settings: settings
        ),
        saveError: saveError,
        writeError: writeError,
        deleteError: deleteError,
        snapshotExists: snapshotExists,
        saveErrorsByAttempt: saveErrorsByAttempt
    )
}

func settingsRepository(_ settings: AppSettings) -> InMemoryAccountRepository {
    accountRepository(settings: settings)
}

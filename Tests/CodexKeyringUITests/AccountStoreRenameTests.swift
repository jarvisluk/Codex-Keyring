import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreRenameTests: XCTestCase {
    func testRenameCanClearAliasAndFallsBackToEmail() async throws {
        let accountID = UUID()
        let account = makeAccount(
            id: accountID,
            alias: "nickname",
            email: "person@example.com"
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: accountID,
                settings: AppSettings()
            )
        )
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        XCTAssertTrue(store.canRename(account, to: "  "))

        store.rename(account, to: "  ")
        try await waitUntil("rename started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("rename completed") {
            store.accounts.first?.alias == "" && !store.isOperationInProgress
        }

        XCTAssertEqual(store.accounts.first?.displayName, "person@example.com")
        XCTAssertEqual(store.statusMessage, "Cleared alias. Account will show as person@example.com.")
    }
}

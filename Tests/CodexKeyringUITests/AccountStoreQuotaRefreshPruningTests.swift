import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreQuotaRefreshPruningTests: XCTestCase {
    func testRefreshPrunesQuotaStatesForRemovedAccounts() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let repository = makeQuotaEnabledRepository(accounts: [account])
        let store = makeStore(repository: repository)

        try await completeInitialRefreshAndAutomaticQuotaRefresh(
            repository: repository,
            store: store
        ) {
            store.quotaStates[accountID] != nil
        }

        store.refresh()
        try await waitForRefreshStarted(
            "refresh after account removal started",
            repository: repository,
            store: store,
            loadCallCount: 3
        )
        repository.resumeNextLoad(returning: makeAccountManifest(settings: quotaEnabledSettings()))
        try await waitUntil("refresh after account removal completed") {
            !store.isOperationInProgress
        }

        XCTAssertTrue(store.accounts.isEmpty)
        XCTAssertTrue(store.quotaStates.isEmpty)
    }
}

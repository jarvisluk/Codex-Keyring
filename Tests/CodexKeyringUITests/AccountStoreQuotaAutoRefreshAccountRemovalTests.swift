import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreQuotaAutoRefreshAccountRemovalTests: XCTestCase {
    func testQuotaAutoRefreshDoesNotRunWhenOnlyAccountsAreRemoved() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let first = makeAccount(id: firstID, alias: "first")
        let second = makeAccount(id: secondID, alias: "second")
        let repository = makeQuotaEnabledRepository(accounts: [first, second])
        let store = makeStore(repository: repository)

        try await completeInitialRefreshAndAutomaticQuotaRefresh(
            "initial quota refresh completed",
            repository: repository,
            store: store
        ) {
            store.quotaStates[firstID] != nil
                && store.quotaStates[secondID] != nil
        }

        let reducedManifest = makeAccountManifest(
            accounts: [first],
            settings: quotaEnabledSettings()
        )
        store.refresh()
        try await waitForRefreshStarted(
            "refresh after account removal started",
            repository: repository,
            store: store,
            loadCallCount: 3
        )
        repository.resumeNextLoad(returning: reducedManifest)
        try await waitUntil("refresh after account removal completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(repository.loadCallCount, 3)
        XCTAssertEqual(store.accounts.map(\.id), [firstID])
        XCTAssertNotNil(store.quotaStates[firstID])
        XCTAssertNil(store.quotaStates[secondID])
    }
}

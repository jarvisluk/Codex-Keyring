import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreQuotaAutoRefreshStatusTests: XCTestCase {
    func testAutomaticQuotaRefreshPreservesExistingVisibleError() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let repository = makeQuotaEnabledRepository(accounts: [account])
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)

        store.lastError = "Previous visible failure."
        store.statusMessage = "Previous visible failure."
        repository.resumeNextLoad()

        try await waitForQuotaRefreshStarted(
            repository: repository,
            store: store,
            loadCallCount: 2
        )
        try await waitUntil("automatic quota loading state set") {
            store.quotaStates[accountID]?.phase == .loading
        }

        XCTAssertEqual(store.lastError, "Previous visible failure.")
        XCTAssertEqual(store.statusMessage, "Previous visible failure.")

        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh completed") {
            store.quotaStates[accountID] != nil
                && !store.isOperationInProgress
        }

        XCTAssertEqual(store.lastError, "Previous visible failure.")
        XCTAssertEqual(store.statusMessage, "Previous visible failure.")
    }

    func testRefreshKeepsAutomaticQuotaRefreshStatusWhileQueued() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let repository = makeQuotaEnabledRepository(accounts: [account])
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)

        repository.resumeNextLoad()
        try await waitForQuotaRefreshStarted(
            repository: repository,
            store: store,
            loadCallCount: 2
        )
        try await waitUntil("automatic quota loading state set") {
            store.quotaStates[accountID]?.phase == .loading
        }

        XCTAssertEqual(store.statusMessage, "Refreshing account quotas...")

        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh completed") {
            !store.isOperationInProgress
        }
    }
}

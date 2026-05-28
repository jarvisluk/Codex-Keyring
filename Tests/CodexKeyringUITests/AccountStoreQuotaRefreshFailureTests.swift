import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreQuotaRefreshFailureTests: XCTestCase {
    func testQuotaRefreshFailureMarksLoadingStatesAsErrors() async throws {
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

        repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: "disk full"))
        try await waitUntil("automatic quota refresh failed") {
            store.quotaStates[accountID]?.phase == .error
                && !store.isQuotaRefreshInProgress
                && !store.isOperationInProgress
        }

        XCTAssertEqual(
            store.quotaStates[accountID]?.message,
            "Local storage operation failed: disk full"
        )
        XCTAssertEqual(store.lastError, "Local storage operation failed: disk full")
        XCTAssertEqual(store.statusMessage, "Local storage operation failed: disk full")
    }
}

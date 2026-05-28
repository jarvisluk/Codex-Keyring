import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreErrorPreservationTests: XCTestCase {
    func testLiveAuthWatcherDoesNotClearExistingUserError() async throws {
        let metadata = AuthMetadata(
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "fingerprint",
            tokenExpiresAt: nil
        )
        let repository = BlockingAccountRepository(manifest: .empty)
        let watcher = ManualLiveAuthWatcher()
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata),
            liveAuthWatcher: watcher
        )

        try await failPendingRefresh(repository: repository, store: store, reason: "disk full")

        watcher.trigger()
        try await waitUntil("watcher sync started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("watcher sync completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.lastError, "Local storage operation failed: disk full")
    }
}

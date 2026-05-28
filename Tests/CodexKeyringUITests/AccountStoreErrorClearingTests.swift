import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreErrorClearingTests: XCTestCase {
    func testClearErrorResetsMatchingStatusMessage() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await completeInitialRefresh(repository: repository, store: store)

        store.reportUserFacingError(CodexKeyringError.fileSystemFailure(reason: "Could not open folder"))
        store.clearError()

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Ready.")
    }

    func testClearErrorPreservesDifferentStatusMessage() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await failPendingRefresh(repository: repository, store: store, reason: "disk full")

        store.statusMessage = "Retry queued."
        store.clearError()

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Retry queued.")
    }
}

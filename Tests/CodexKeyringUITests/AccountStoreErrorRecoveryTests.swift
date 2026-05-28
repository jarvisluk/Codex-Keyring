import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreErrorRecoveryTests: XCTestCase {
    func testStartupErrorSurvivesSuccessfulInitialRefresh() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let startupError = CodexKeyringError.fileSystemFailure(
            reason: "Could not prepare Codex Keyring storage directories: permission denied"
        )
        let store = makeStore(repository: repository, startupError: startupError)

        try await waitForRefreshStarted(repository: repository, store: store)

        XCTAssertEqual(store.lastError, startupError.localizedDescription)
        XCTAssertEqual(store.statusMessage, startupError.localizedDescription)

        try await finishPendingRefresh("initial refresh completed", repository: repository, store: store)

        XCTAssertEqual(store.lastError, startupError.localizedDescription)
        XCTAssertEqual(store.statusMessage, startupError.localizedDescription)
    }

    func testSuccessfulRetryClearsPreviousError() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await failPendingRefresh(repository: repository, store: store, reason: "disk full")
        try await retryAndCompleteRefresh(repository: repository, store: store)

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Refreshed accounts.")
    }

    func testReportedUserFacingErrorSetsStatusAndClearsOnSuccessfulRetry() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await completeInitialRefresh(repository: repository, store: store)

        store.reportUserFacingError(CodexKeyringError.fileSystemFailure(reason: "Could not open folder"))

        XCTAssertEqual(store.lastError, "Local storage operation failed: Could not open folder")
        XCTAssertEqual(store.statusMessage, "Local storage operation failed: Could not open folder")

        try await retryAndCompleteRefresh(repository: repository, store: store)

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Refreshed accounts.")
    }
}

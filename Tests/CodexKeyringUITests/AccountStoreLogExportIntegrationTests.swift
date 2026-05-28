import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreLogExportIntegrationTests: XCTestCase {
    func testSuccessfulLogExportClearsPreviousError() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let logService = RecordingLogService()
        let store = makeStore(repository: repository, logService: logService)

        try await waitForRefreshStarted(repository: repository, store: store)
        repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: "disk full"))
        try await waitUntil("initial refresh failed") {
            store.lastError == "Local storage operation failed: disk full"
                && !store.isOperationInProgress
        }

        let destination = URL(fileURLWithPath: "/tmp/codex-keyring-export.log.txt")
        store.exportLogs(to: destination)

        try await waitUntil("log export completed") {
            store.statusMessage == "Logs exported to \(destination.path)."
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(logService.exportedURLs, [destination])
    }

    func testLogExportShowsBusyStateAndIgnoresDuplicateRequests() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let logService = BlockingLogService()
        let store = makeStore(repository: repository, logService: logService)

        try await waitForRefreshStarted(repository: repository, store: store)
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }
        XCTAssertTrue(store.canExportLogs)

        let firstDestination = URL(fileURLWithPath: "/tmp/codex-keyring-first.log.txt")
        let secondDestination = URL(fileURLWithPath: "/tmp/codex-keyring-second.log.txt")
        store.exportLogs(to: firstDestination)

        try await waitUntil("log export started") {
            logService.exportStartedCount == 1
                && store.isLogExportInProgress
        }
        XCTAssertFalse(store.canExportLogs)
        XCTAssertTrue(store.isStatusBusy)
        XCTAssertFalse(store.isOperationInProgress)

        store.exportLogs(to: secondDestination)

        XCTAssertEqual(logService.exportStartedCount, 1)
        XCTAssertEqual(logService.exportedURLs, [firstDestination])

        logService.resumeExport()
        try await waitUntil("log export completed") {
            !store.isLogExportInProgress
                && store.statusMessage == "Logs exported to \(firstDestination.path)."
        }
        XCTAssertFalse(store.isOperationInProgress)
        XCTAssertFalse(store.isStatusBusy)
        XCTAssertTrue(store.canExportLogs)

        XCTAssertEqual(logService.exportedURLs, [firstDestination])
    }

    func testFailedLogExportRestoresAvailabilityAndShowsError() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let logService = FailingLogService(
            error: CodexKeyringError.fileSystemFailure(reason: "permission denied")
        )
        let store = makeStore(repository: repository, logService: logService)

        try await waitForRefreshStarted(repository: repository, store: store)
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        let destination = URL(fileURLWithPath: "/tmp/codex-keyring-denied.log.txt")
        store.exportLogs(to: destination)

        try await waitUntil("log export failed") {
            !store.isLogExportInProgress
                && store.lastError == "Local storage operation failed: permission denied"
        }

        XCTAssertEqual(store.statusMessage, "Local storage operation failed: permission denied")
        XCTAssertFalse(store.isStatusBusy)
        XCTAssertTrue(store.canExportLogs)
        XCTAssertEqual(logService.exportedURLs, [destination])
    }
}

import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreLoginBusyStateTests: XCTestCase {
    func testLoginBusyStateBlocksOtherAccountActions() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let loginService = BlockingLoginService()
        let store = makeStore(
            repository: repository,
            loginService: loginService
        )

        try await completeInitialRefresh(repository: repository, store: store)

        store.loginNewCodexAccount()
        try await waitUntil("login flow started") {
            loginService.startedCount == 1
                && store.isLoginInProgress
                && store.isOperationInProgress
        }

        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertFalse(store.canAddCurrentLogin)
        XCTAssertTrue(store.isStatusBusy)

        store.refresh()
        store.importAccount(from: URL(fileURLWithPath: "/tmp/imported-auth.json"))
        XCTAssertEqual(repository.loadCallCount, 1)

        loginService.fail(with: CodexKeyringError.codexLoginFailed(reason: "cancelled"))
        try await waitUntil("login flow failed") {
            !store.isLoginInProgress
                && !store.isOperationInProgress
                && store.lastError == "Codex login failed: cancelled"
        }

        XCTAssertTrue(store.canLoginNewAccount)
        XCTAssertTrue(store.canImportAccount)
        XCTAssertTrue(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
    }

    func testLoginCanBeCancelledWhileWaitingForBrowserCallback() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let loginService = BlockingLoginService()
        let store = makeStore(
            repository: repository,
            loginService: loginService
        )

        try await completeInitialRefresh(repository: repository, store: store)

        store.loginNewCodexAccount()
        try await waitUntil("login flow started") {
            loginService.startedCount == 1
                && store.isLoginInProgress
                && store.isOperationInProgress
        }

        store.cancelLoginNewCodexAccount()

        try await waitUntil("login flow cancelled") {
            !store.isLoginInProgress
                && !store.isOperationInProgress
                && store.statusMessage == "Codex login cancelled."
        }

        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.canLoginNewAccount)
        XCTAssertTrue(store.canImportAccount)
        XCTAssertTrue(store.canRefreshAccounts)
    }
}

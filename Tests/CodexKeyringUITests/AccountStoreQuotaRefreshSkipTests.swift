import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreQuotaRefreshSkipTests: XCTestCase {
    func testRefreshQuotasSkipsWhenNoAccountsAreSaved() async throws {
        let repository = makeQuotaEnabledRepository(snapshotExists: false)
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.refreshQuotasNow()

        XCTAssertEqual(store.statusMessage, "No saved accounts to refresh quotas for.")
        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertTrue(store.quotaStates.isEmpty)
        XCTAssertFalse(store.isQuotaRefreshInProgress)
        XCTAssertFalse(store.isOperationInProgress)
    }

    func testRefreshQuotasSkipsWhenNetworkAPIsAreDisabled() async throws {
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

        store.lastError = "Previous export failed."
        store.setAllowNetworkQuotaAPIs(false)

        try await waitUntil("network quota setting update started") {
            repository.loadCallCount == 3 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("network quota setting update completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.quotaStates.isEmpty)
        XCTAssertEqual(store.statusMessage, "Network quota API calls disabled.")

        store.lastError = "Stale failure."
        store.refreshQuotasNow()

        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.quotaStates.isEmpty)
        XCTAssertEqual(store.statusMessage, "Network quota API calls are disabled.")
        XCTAssertEqual(repository.loadCallCount, 3)
        XCTAssertFalse(store.isQuotaRefreshInProgress)
        XCTAssertFalse(store.isOperationInProgress)
    }

    func testQuotaRefreshExplainsWhenOnlyAPIKeyAccountsAreSaved() async throws {
        let accountID = UUID()
        var account = makeAccount(id: accountID)
        account.plan = "API key"
        account.authMode = "api-key"
        let repository = makeQuotaEnabledRepository(accounts: [account])
        let store = makeStore(repository: repository)

        try await completeInitialRefreshAndAutomaticQuotaRefresh(
            repository: repository,
            store: store
        ) {
            store.quotaStates[accountID]?.phase == .unsupported
        }

        XCTAssertEqual(store.statusMessage, "No ChatGPT/Codex OAuth accounts expose quota.")
    }
}

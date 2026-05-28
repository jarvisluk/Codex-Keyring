import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreOperationAvailabilityTests: XCTestCase {
    func testOperationBusyStateCoversSettingUpdates() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)
        XCTAssertTrue(store.isOperationInProgress)
        try await finishPendingRefresh("initial refresh completed", repository: repository, store: store)

        store.setRestartCodexAppAfterSwitch(false)
        try await waitUntil("setting update started") {
            repository.loadCallCount == 2
                && store.isOperationInProgress
        }

        repository.resumeNextLoad()
        try await waitUntil("setting update finished") {
            !store.isOperationInProgress
        }

        XCTAssertFalse(store.settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(store.statusMessage, "Codex App restart after switching disabled.")
    }

    func testActionAvailabilityTracksAccountsAndBusyState() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let repository = makeQuotaEnabledRepository()
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)
        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertTrue(store.isStatusBusy)

        try await finishPendingRefresh(
            "initial refresh completed without accounts",
            repository: repository,
            store: store
        )

        XCTAssertTrue(store.canLoginNewAccount)
        XCTAssertTrue(store.canImportAccount)
        XCTAssertTrue(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertFalse(store.isStatusBusy)

        store.refresh()
        try await waitForRefreshStarted(
            "refresh with first account started",
            repository: repository,
            store: store,
            loadCallCount: 2
        )
        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        let manifestWithAccount = makeAccountManifest(
            accounts: [account],
            settings: quotaEnabledSettings()
        )
        repository.resumeNextLoad(returning: manifestWithAccount)

        try await waitForQuotaRefreshStarted(
            repository: repository,
            store: store,
            loadCallCount: 3
        )
        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertFalse(store.canSwitch(to: account))
        XCTAssertFalse(store.canRemove(account))
        XCTAssertFalse(store.canBeginRename(account))
        XCTAssertFalse(store.canRename(account, to: "renamed"))
        XCTAssertTrue(store.isStatusBusy)

        repository.resumeNextLoad(returning: manifestWithAccount)
        try await waitUntil("automatic quota refresh completed") {
            store.canRefreshQuotas && !store.isStatusBusy
        }

        XCTAssertEqual(store.accounts.map(\.id), [accountID])
        XCTAssertTrue(store.canRefreshAccounts)
        XCTAssertTrue(store.canSwitch(to: account))
        XCTAssertTrue(store.canRemove(account))
        XCTAssertTrue(store.canBeginRename(account))
        XCTAssertTrue(store.canRename(account, to: "renamed"))
    }
}

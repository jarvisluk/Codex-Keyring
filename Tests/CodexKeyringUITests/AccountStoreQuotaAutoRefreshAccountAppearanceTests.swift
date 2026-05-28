import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreQuotaAutoRefreshAccountAppearanceTests: XCTestCase {
    func testQuotaAutoRefreshStartsWhenFirstAccountAppears() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let repository = makeQuotaEnabledRepository()
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed without quota load") {
            repository.loadCallCount == 1 && !store.isOperationInProgress
        }

        store.refresh()
        try await waitForRefreshStarted(
            "refresh with first account started",
            repository: repository,
            store: store,
            loadCallCount: 2
        )
        let manifestWithAccount = makeAccountManifest(
            accounts: [account],
            settings: quotaEnabledSettings()
        )
        repository.resumeNextLoad(returning: manifestWithAccount)

        try await waitForQuotaRefreshStarted(
            "automatic quota refresh for first account started",
            repository: repository,
            store: store,
            loadCallCount: 3
        )
        repository.resumeNextLoad(returning: manifestWithAccount)
        try await waitUntil("automatic quota refresh for first account completed") {
            store.quotaStates[accountID] != nil && !store.isOperationInProgress
        }
    }

    func testQuotaAutoRefreshRunsWhenAdditionalAccountAppears() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let first = makeAccount(id: firstID, alias: "first")
        let second = makeAccount(id: secondID, alias: "second")
        let repository = makeQuotaEnabledRepository(accounts: [first])
        let store = makeStore(repository: repository)

        try await completeInitialRefreshAndAutomaticQuotaRefresh(
            "initial quota refresh completed",
            repository: repository,
            store: store
        ) {
            store.quotaStates[firstID] != nil
        }

        let expandedManifest = makeAccountManifest(
            accounts: [first, second],
            settings: quotaEnabledSettings()
        )
        store.refresh()
        try await waitForRefreshStarted(
            "refresh with additional account started",
            repository: repository,
            store: store,
            loadCallCount: 3
        )
        repository.resumeNextLoad(returning: expandedManifest)

        try await completeAutomaticQuotaRefresh(
            "quota refresh for additional account completed",
            repository: repository,
            store: store,
            loadCallCount: 4,
            returning: expandedManifest
        ) {
            store.quotaStates[secondID] != nil
        }
    }
}

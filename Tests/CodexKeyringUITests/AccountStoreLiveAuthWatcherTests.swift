import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreLiveAuthWatcherTests: XCTestCase {
    func testLiveAuthChangesCoalesceWhileSyncIsPending() async throws {
        let metadata = AuthMetadata(
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "fingerprint",
            tokenExpiresAt: nil
        )
        let account = CodexAccount(
            id: UUID(),
            alias: "person",
            email: metadata.email,
            plan: metadata.plan,
            authMode: metadata.authMode,
            accountIdentifier: metadata.accountIdentifier,
            snapshotFileName: "person.auth.json",
            fingerprint: metadata.fingerprint,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: AppSettings()
            )
        )
        let watcher = ManualLiveAuthWatcher()
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata),
            liveAuthWatcher: watcher
        )

        try await waitForRefreshStarted(repository: repository, store: store)
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            repository.loadCallCount == 1 && !store.isOperationInProgress
        }

        watcher.trigger()
        try await waitUntil("first live auth sync started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }

        watcher.trigger()
        watcher.trigger()
        repository.resumeNextLoad()
        try await waitUntil("coalesced follow-up sync started") {
            repository.loadCallCount == 3 && store.isOperationInProgress
        }

        repository.resumeNextLoad()
        try await waitUntil("coalesced live auth sync completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(repository.loadCallCount, 3)
    }
}

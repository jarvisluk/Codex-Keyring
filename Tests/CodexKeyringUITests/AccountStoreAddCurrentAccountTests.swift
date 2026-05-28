import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreAddCurrentAccountTests: XCTestCase {
    func testAddCurrentAccountSkipsWhenCurrentAuthIsUnreadable() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await completeInitialRefresh(repository: repository, store: store)

        store.addCurrentAccount(alias: nil)

        XCTAssertEqual(store.statusMessage, "No readable Codex auth.json to save.")
        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertFalse(store.isOperationInProgress)
    }

    func testAddCurrentAccountShowsWarningWhenAgentPreferencesCannotBeSaved() async throws {
        let metadata = AuthMetadata(
            email: "new@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "new-account",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: nil
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(preserveAgentPreferencesPerAccount: true)
            )
        )
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata),
            agentPreferencesPort: ThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "permission denied")
            )
        )

        try await completeInitialRefresh(repository: repository, store: store)

        store.addCurrentAccount(alias: "new")
        try await waitUntil("add current auth started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("add current auth completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.accounts.first?.alias, "new")
        XCTAssertTrue(store.statusMessage.contains("Saved current Codex auth as new."))
        XCTAssertTrue(store.statusMessage.contains("Agent settings were not saved for this account"))
        XCTAssertTrue(store.statusMessage.contains("permission denied"))
    }
}

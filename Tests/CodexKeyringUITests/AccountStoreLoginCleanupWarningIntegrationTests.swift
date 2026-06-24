import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreLoginCleanupWarningIntegrationTests: XCTestCase {
    func testLoginSuccessShowsTemporaryCleanupWarning() async throws {
        let oldMetadata = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "old",
            fingerprint: "old",
            tokenExpiresAt: nil
        )
        let newMetadata = AuthMetadata(
            email: "new@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "new",
            fingerprint: "new",
            tokenExpiresAt: nil
        )
        let liveURL = URL(fileURLWithPath: "/tmp/auth.json")
        let preLoginURL = URL(fileURLWithPath: "/tmp/pre-login.json")
        let newLoginURL = URL(fileURLWithPath: "/tmp/new-login.json")
        let repository = BlockingAccountRepository(manifest: .empty)
        let installer = StagedLoginInstaller(
            liveAuthFileURL: liveURL,
            preLoginURL: preLoginURL,
            newLoginURL: newLoginURL,
            cleanupError: CodexKeyringError.fileSystemFailure(reason: "cleanup denied")
        )
        let store = makeStore(
            repository: repository,
            authReader: MappedAuthReader([
                liveURL: oldMetadata,
                newLoginURL: newMetadata
            ]),
            loginService: NoopLoginService(),
            installer: installer
        )

        try await completeInitialRefresh(repository: repository, store: store)

        store.loginNewCodexAccount()
        try await waitUntil("login add account load started") {
            repository.loadCallCount == 2 && store.isLoginInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("login refresh state load started") {
            repository.loadCallCount == 3 && store.isLoginInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("login completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.accounts.map(\.alias), ["new"])
        XCTAssertTrue(store.statusMessage.contains("Saved new Codex login as new."))
        XCTAssertTrue(store.statusMessage.contains("Temporary login files could not be cleaned up"))
        XCTAssertTrue(store.statusMessage.contains("Could not remove a staged auth copy"))
        XCTAssertFalse(store.statusMessage.contains(preLoginURL.path))
        XCTAssertFalse(store.statusMessage.contains(newLoginURL.path))
        XCTAssertTrue(store.statusMessage.contains("cleanup denied"))
    }
}

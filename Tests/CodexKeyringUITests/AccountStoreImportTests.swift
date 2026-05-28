import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreImportTests: XCTestCase {
    func testImportReleasesAccessScopeImmediatelyWhenBusy() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let scope = RecordingURLAccessScope()
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)

        store.importAccount(
            from: URL(fileURLWithPath: "/tmp/imported-auth.json"),
            accessScope: scope.makeScope()
        )

        XCTAssertEqual(scope.stopCount, 1)
        XCTAssertEqual(repository.loadCallCount, 1)
    }

    func testImportKeepsAccessScopeUntilAsyncOperationFinishes() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let scope = RecordingURLAccessScope()
        let metadata = AuthMetadata(
            email: "imported@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "imported-account",
            fingerprint: "imported-fingerprint",
            tokenExpiresAt: nil
        )
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata)
        )

        try await completeInitialRefresh(repository: repository, store: store)

        store.importAccount(
            from: URL(fileURLWithPath: "/tmp/imported-auth.json"),
            accessScope: scope.makeScope()
        )
        try await waitUntil("import load started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }

        XCTAssertEqual(scope.stopCount, 0)

        repository.resumeNextLoad()
        try await waitUntil("import completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(scope.stopCount, 1)
        XCTAssertEqual(store.accounts.map(\.email), ["imported@example.com"])
    }

    func testImportAccountDoesNotMarkImportedSnapshotActive() async throws {
        let active = makeAccount(id: UUID(), alias: "current")
        let importedMetadata = AuthMetadata(
            email: "imported@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "imported-account",
            fingerprint: "imported-fingerprint",
            tokenExpiresAt: nil
        )
        let importURL = URL(fileURLWithPath: "/tmp/imported-auth.json")
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [active],
                activeAccountID: active.id,
                settings: AppSettings()
            )
        )
        let store = makeStore(
            repository: repository,
            authReader: MappedAuthReader([
                URL(fileURLWithPath: "/tmp/auth.json"): authMetadata(from: active),
                importURL: importedMetadata
            ])
        )

        try await completeInitialRefresh(repository: repository, store: store)

        store.importAccount(from: importURL)
        try await waitUntil("import load started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("import completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.accounts.map(\.email).sorted(), ["current@example.com", "imported@example.com"])
        XCTAssertEqual(store.activeAccountID, active.id)
        XCTAssertEqual(store.activeAccount?.id, active.id)
        XCTAssertEqual(store.currentAuthMetadata?.fingerprint, active.fingerprint)
        XCTAssertEqual(
            store.statusMessage,
            "Imported account imported. Current Codex auth was not switched."
        )
    }
}

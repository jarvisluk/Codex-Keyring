import XCTest
@testable import CodexKeyringDomain

final class SyncLiveAuthUseCaseGuardTests: XCTestCase {
    func testSyncLiveAuthAllowsMissingLiveAuthAsNoop() async throws {
        let saved = account(id: UUID(), alias: "primary", metadata: metadata(email: "a@example.com", fingerprint: "fp-A"))
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await syncLiveAuthUseCase(repository: repository)()

        XCTAssertEqual(result, .noop)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
        XCTAssertEqual(repository.saveCount, 0)
    }

    func testSyncLiveAuthFailsWhenLiveAuthIsUnreadable() async throws {
        let repository = accountRepository()

        do {
            _ = try await syncLiveAuthUseCase(
                repository: repository,
                authReader: ThrowingAuthReader(error: .authFileUnreadable)
            )()
            XCTFail("Expected unreadable live auth to fail sync.")
        } catch CodexKeyringError.authFileUnreadable {
            XCTAssertEqual(repository.snapshotWriteCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSyncLiveAuthSkipsApiKeyIdentifier() async throws {
        let liveURL = testAuthURL("live-auth.json")
        // Two API-key accounts share the placeholder identifier "api-key";
        // we must not let a fingerprint drift cause cross-account writes.
        let liveAuth = AuthMetadata(
            email: "api@example.com",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "live-fp",
            tokenExpiresAt: nil
        )
        let existing = AuthMetadata(
            email: "other@example.com",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "different-fp",
            tokenExpiresAt: nil
        )
        let stored = account(id: UUID(), alias: "api", metadata: existing)
        let registry = AuthFileRegistry([liveURL: liveAuth])
        let repository = accountRepository(accounts: [stored], activeAccountID: stored.id)

        let result = try await syncLiveAuthUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL
        )()

        XCTAssertEqual(result, .noop)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
    }

    func testSyncLiveAuthSkipsUnknownChatGPTIdentifier() async throws {
        let liveURL = testAuthURL("live-auth.json")
        let liveAuth = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: AuthMetadata.unknownChatGPTAccountIdentifier,
            fingerprint: "live-fp",
            tokenExpiresAt: nil
        )
        let existing = AuthMetadata(
            email: "other@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: AuthMetadata.unknownChatGPTAccountIdentifier,
            fingerprint: "different-fp",
            tokenExpiresAt: nil
        )
        let stored = account(id: UUID(), alias: "chatgpt", metadata: existing)
        let registry = AuthFileRegistry([liveURL: liveAuth])
        let repository = accountRepository(accounts: [stored], activeAccountID: stored.id)

        let result = try await syncLiveAuthUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL
        )()

        XCTAssertEqual(result, .noop)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
        XCTAssertEqual(repository.saveCount, 0)
    }
}

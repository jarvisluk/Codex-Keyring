import XCTest
@testable import CodexKeyringDomain

final class SyncLiveAuthUseCaseMetadataTests: XCTestCase {
    func testSyncLiveAuthRefreshesMetadataWhenFingerprintIsUnchanged() async throws {
        let original = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: nil
        )
        let refreshed = AuthMetadata(
            email: "new@example.com",
            plan: "business",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 300)
        )
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: refreshed])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await syncLiveAuthUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            clock: FixedClock(Date(timeIntervalSince1970: 400))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertFalse(result.didUpdateSnapshot)
        XCTAssertTrue(result.didUpdateMetadata)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
        XCTAssertEqual(updated.email, "new@example.com")
        XCTAssertEqual(updated.plan, "business")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 400))
    }

    func testSyncLiveAuthDoesNotOverwriteUsefulMetadataWithPlaceholders() async throws {
        let original = AuthMetadata(
            email: "known@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let sparse = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 200)
        )
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: sparse])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        _ = try await syncLiveAuthUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            clock: FixedClock(Date(timeIntervalSince1970: 400))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertEqual(updated.email, "known@example.com")
        XCTAssertEqual(updated.plan, "plus")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 200))
    }
}

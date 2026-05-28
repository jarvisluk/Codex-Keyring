import XCTest
@testable import CodexKeyringDomain

final class SyncLiveAuthUseCaseSnapshotTests: XCTestCase {
    func testSyncLiveAuthCapturesRotatedRefreshToken() async throws {
        let identifier = "user-123"
        let original = AuthMetadata(
            email: "user@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fingerprint-v1",
            tokenExpiresAt: nil
        )
        let rotated = AuthMetadata(
            email: "user@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fingerprint-v2",
            tokenExpiresAt: nil
        )
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: rotated])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await syncLiveAuthUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            clock: FixedClock(Date(timeIntervalSince1970: 200))
        )()

        let manifest = try await repository.load()
        XCTAssertTrue(result.didUpdateSnapshot)
        XCTAssertTrue(result.didUpdateMetadata)
        XCTAssertFalse(result.didReassignActive)
        XCTAssertEqual(result.updatedAccountID, saved.id)
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.source, liveURL)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, saved.id)
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "fingerprint-v2")
        XCTAssertEqual(manifest.activeAccountID, saved.id)
    }
}

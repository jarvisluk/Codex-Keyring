import XCTest
@testable import CodexKeyringDomain

final class SwitchAccountUseCaseValidationTests: XCTestCase {
    func testSwitchAccountValidatesSnapshotBeforeBackupOrInstall() async throws {
        let fixture = SwitchAccountValidationFixture()

        do {
            _ = try await fixture.switchToNewAccount(authReader: fixture.snapshotFailingReader())
            XCTFail("Expected switch to fail before installing an unreadable snapshot.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await fixture.repository.load()
        XCTAssertEqual(saved.activeAccountID, fixture.oldAccount.id)
        XCTAssertEqual(fixture.registry.metadata(for: fixture.liveURL)?.fingerprint, "old")
        fixture.assertNoInstallAttempt()
    }

    func testSwitchAccountReportsMissingSnapshotWhenSnapshotReadIsMissing() async throws {
        let fixture = SwitchAccountValidationFixture(seedSnapshot: false)

        do {
            _ = try await fixture.switchToNewAccount(
                authReader: MockAuthReader(registry: fixture.registry)
            )
            XCTFail("Expected switch to fail when the snapshot is missing.")
        } catch CodexKeyringError.snapshotMissing(let accountID) {
            XCTAssertEqual(accountID, fixture.newAccount.id)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        fixture.assertNoInstallAttempt()
        fixture.assertNoManifestWrite()
    }

    func testSwitchAccountValidatesSnapshotBeforeSyncingRotatedLiveAuth() async throws {
        let stableIdentifier = "old-account"
        let storedMetadata = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: stableIdentifier,
            fingerprint: "old-stale",
            tokenExpiresAt: nil
        )
        let oldLive = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: stableIdentifier,
            fingerprint: "old-rotated",
            tokenExpiresAt: nil
        )
        let fixture = SwitchAccountValidationFixture(
            oldMetadata: storedMetadata,
            liveMetadata: oldLive
        )

        do {
            _ = try await fixture.switchToNewAccount(authReader: fixture.snapshotFailingReader())
            XCTFail("Expected switch to fail before syncing live auth.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await fixture.repository.load()
        XCTAssertEqual(
            saved.accounts.first { $0.id == fixture.oldAccount.id }?.fingerprint,
            "old-stale"
        )
        XCTAssertEqual(saved.activeAccountID, fixture.oldAccount.id)
        fixture.assertNoInstallAttempt()
        fixture.assertNoManifestWrite()
    }

    func testSwitchAccountFailsWhenLiveAuthIsUnreadableBeforeBackupOrInstall() async throws {
        let fixture = SwitchAccountValidationFixture()

        do {
            _ = try await fixture.switchToNewAccount(authReader: fixture.liveFailingReader())
            XCTFail("Expected switch to fail before overwriting an unreadable live auth.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await fixture.repository.load()
        XCTAssertEqual(saved.activeAccountID, fixture.oldAccount.id)
        XCTAssertEqual(fixture.registry.metadata(for: fixture.liveURL)?.fingerprint, "old")
        fixture.assertNoInstallAttempt()
    }
}

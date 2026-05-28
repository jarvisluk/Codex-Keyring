import XCTest
@testable import CodexKeyringDomain

final class RefreshStateUseCaseTests: XCTestCase {
    func testRefreshStateAdoptsRotatedFingerprintForActiveAccount() async throws {
        let fixture = RotatedLiveAuthRefreshFixture()

        let state = try await fixture.refresh()

        let manifest = try await fixture.repository.load()
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "fp-A-v2")
        XCTAssertEqual(state.activeAccountID, fixture.savedAccount.id)
        XCTAssertEqual(state.currentAuthMetadata?.fingerprint, "fp-A-v2")
        XCTAssertEqual(fixture.repository.snapshotWriteCount, 1)
    }

    func testRefreshStateFailsWhenRotatedLiveAuthCannotBeSavedBack() async throws {
        let writeError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let fixture = RotatedLiveAuthRefreshFixture(writeError: writeError)

        do {
            _ = try await fixture.refresh()
            XCTFail("Expected refresh to fail when current live auth cannot be preserved.")
        } catch CodexKeyringError.currentAuthSyncFailed(let reason) {
            XCTAssertTrue(reason.contains("disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await fixture.repository.load()
        XCTAssertEqual(fixture.repository.snapshotWriteCount, 1)
        XCTAssertEqual(fixture.repository.lastSnapshotWrite?.accountID, fixture.savedAccount.id)
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "fp-A-v1")
        XCTAssertEqual(manifest.activeAccountID, fixture.savedAccount.id)
    }

    func testRefreshStateAllowsMissingLiveAuthWithoutClearingSavedAccounts() async throws {
        let existing = account(id: UUID(), alias: "A", metadata: metadata(email: "a@example.com", fingerprint: "fp-A"))
        let repository = accountRepository(accounts: [existing], activeAccountID: existing.id)

        let state = try await refreshStateUseCase(repository: repository)()

        XCTAssertEqual(state.accounts.map(\.id), [existing.id])
        XCTAssertEqual(state.activeAccountID, existing.id)
        XCTAssertNil(state.currentAuthMetadata)
    }

    func testRefreshStateFailsWhenLiveAuthIsUnreadable() async throws {
        let repository = accountRepository()

        do {
            _ = try await refreshStateUseCase(
                repository: repository,
                authReader: ThrowingAuthReader(error: .authFileUnreadable)
            )()
            XCTFail("Expected unreadable live auth to fail refresh.")
        } catch CodexKeyringError.authFileUnreadable {
            XCTAssertEqual(repository.snapshotWriteCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAccountStateFallsBackToStableIdentifierWhenFingerprintRotates() throws {
        let identifier = "user-A"
        let stored = metadata(
            email: "a@example.com",
            fingerprint: "fp-A-v1",
            accountIdentifier: identifier
        )
        let live = metadata(
            email: "a@example.com",
            fingerprint: "fp-A-v2",
            accountIdentifier: identifier
        )
        let account = account(id: UUID(), alias: "A", metadata: stored)

        let state = AccountState(
            accounts: [account],
            activeAccountID: nil,
            settings: AppSettings(),
            currentAuthMetadata: live
        )

        XCTAssertEqual(state.activeAccount?.id, account.id)
    }
}

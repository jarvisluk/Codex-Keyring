import XCTest
@testable import CodexKeyringDomain

final class LoginNewAccountUseCaseTests: XCTestCase {
    func testLoginNewAccountRestoresPreviousLiveAuthAndSavesInactiveSnapshot() async throws {
        let fixture = LoginNewAccountUseCaseFixture()
        let recorder = URLRecorder()
        let result = try await fixture.login(openAuthURL: { url in
            recorder.url = url
        })

        let saved = try await fixture.repository.load()
        XCTAssertEqual(recorder.url?.absoluteString, "https://example.test/login")
        XCTAssertEqual(fixture.registry.metadata(for: fixture.liveURL)?.fingerprint, "old")
        XCTAssertEqual(saved.activeAccountID, fixture.oldAccount.id)
        XCTAssertEqual(saved.accounts.map(\.alias).sorted(), ["new", "old"])
        XCTAssertEqual(result.state.activeAccountID, fixture.oldAccount.id)
        XCTAssertEqual(result.savedAlias, "new")
    }

    func testLoginNewAccountReturnsCleanupWarningWhenStageRemovalFailsAfterSuccess() async throws {
        let fixture = LoginNewAccountUseCaseFixture(
            removeStagedError: CodexKeyringError.fileSystemFailure(reason: "cleanup denied")
        )

        let result = try await fixture.login()

        let saved = try await fixture.repository.load()
        XCTAssertEqual(saved.accounts.map(\.alias).sorted(), ["new", "old"])
        XCTAssertEqual(fixture.registry.metadata(for: fixture.liveURL)?.fingerprint, "old")
        XCTAssertEqual(fixture.registry.metadata(for: fixture.preLoginStage)?.fingerprint, "old")
        XCTAssertEqual(fixture.registry.metadata(for: fixture.newLoginStage)?.fingerprint, "new")
        XCTAssertEqual(fixture.installer.removeStagedCount, 2)
        XCTAssertTrue(result.cleanupWarningReason?.contains("Could not remove a staged auth copy") == true)
        XCTAssertFalse(result.cleanupWarningReason?.contains(fixture.preLoginStage.path) == true)
        XCTAssertFalse(result.cleanupWarningReason?.contains(fixture.newLoginStage.path) == true)
        XCTAssertTrue(result.cleanupWarningReason?.contains("cleanup denied") == true)
    }

    func testLoginNewAccountKeepsPreviousAuthStageWhenRestoreFails() async throws {
        let fixture = LoginNewAccountUseCaseFixture(
            restoreError: CodexKeyringError.fileSystemFailure(reason: "restore failed")
        )

        do {
            _ = try await fixture.login()
            XCTFail("Expected login flow to fail when previous live auth cannot be restored.")
        } catch CodexKeyringError.previousAuthRestoreFailed(let reason, let recoveryPath) {
            XCTAssertTrue(reason.contains("restore failed"))
            XCTAssertEqual(recoveryPath, "/tmp/pre-login-1.json")
            XCTAssertTrue(
                CodexKeyringError.previousAuthRestoreFailed(
                    reason: reason,
                    recoveryPath: recoveryPath
                ).localizedDescription.contains("A recovery copy was kept at /tmp/pre-login-1.json")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await fixture.repository.load()
        XCTAssertEqual(fixture.registry.metadata(for: fixture.liveURL)?.fingerprint, "new")
        XCTAssertEqual(fixture.registry.metadata(for: fixture.preLoginStage)?.fingerprint, "old")
        XCTAssertNil(fixture.registry.metadata(for: fixture.newLoginStage))
        XCTAssertEqual(saved.accounts.map(\.alias), ["old"])
        XCTAssertEqual(fixture.installer.restoreCount, 2)
    }

    func testLoginNewAccountCleansStagesWhenSaveFailsAfterRestoreSucceeds() async throws {
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let fixture = LoginNewAccountUseCaseFixture(saveError: saveError)

        do {
            _ = try await fixture.login()
            XCTFail("Expected login flow to fail when saving the new account fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        XCTAssertEqual(fixture.registry.metadata(for: fixture.liveURL)?.fingerprint, "old")
        XCTAssertNil(fixture.registry.metadata(for: fixture.preLoginStage))
        XCTAssertNil(fixture.registry.metadata(for: fixture.newLoginStage))
        XCTAssertEqual(fixture.installer.restoreCount, 1)
    }
}

import XCTest
@testable import CodexKeyringDomain

final class SwitchAccountUseCaseRollbackTests: XCTestCase {
    func testSwitchAccountRestoresPreviousLiveAuthWhenManifestSaveFails() async throws {
        let scenario = makeSwitchRollbackScenario()
        let oldAccount = try XCTUnwrap(scenario.oldAccount)

        do {
            _ = try await scenario.useCase()(
                accountID: scenario.newAccount.id,
                restartCodexApp: false
            )
            XCTFail("Expected switch to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, scenario.saveError.localizedDescription)
        }

        let saved = try await scenario.repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(scenario.registry.metadata(for: scenario.liveURL)?.fingerprint, "old")
        XCTAssertEqual(scenario.installer.backupCount, 1)
        XCTAssertEqual(scenario.installer.restoreCount, 1)
    }

    func testSwitchAccountReportsWhenPreviousAuthRestoreFailsAfterManifestSaveFails() async throws {
        let restoreError = CodexKeyringError.fileSystemFailure(reason: "restore denied")
        let scenario = makeSwitchRollbackScenario(restoreError: restoreError)
        let oldAccount = try XCTUnwrap(scenario.oldAccount)

        do {
            _ = try await scenario.useCase()(
                accountID: scenario.newAccount.id,
                restartCodexApp: false
            )
            XCTFail("Expected switch to fail when manifest save and live auth restore both fail.")
        } catch CodexKeyringError.previousAuthRestoreFailed(let reason, let recoveryPath) {
            XCTAssertTrue(reason.contains(scenario.saveError.localizedDescription))
            XCTAssertTrue(reason.contains(restoreError.localizedDescription))
            XCTAssertEqual(recoveryPath, "/tmp/backup-1.json")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await scenario.repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(scenario.registry.metadata(for: scenario.liveURL)?.fingerprint, "new")
        XCTAssertEqual(
            scenario.registry.metadata(for: URL(fileURLWithPath: "/tmp/backup-1.json"))?.fingerprint,
            "old"
        )
        XCTAssertEqual(scenario.installer.backupCount, 1)
        XCTAssertEqual(scenario.installer.restoreCount, 1)
    }

    func testSwitchAccountRemovesLiveAuthOnSaveFailureWhenNoPreviousAuthExisted() async throws {
        let scenario = makeSwitchRollbackScenario(hasPreviousAuth: false)

        do {
            _ = try await scenario.useCase()(
                accountID: scenario.newAccount.id,
                restartCodexApp: false
            )
            XCTFail("Expected switch to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, scenario.saveError.localizedDescription)
        }

        let saved = try await scenario.repository.load()
        XCTAssertNil(saved.activeAccountID)
        XCTAssertNil(scenario.registry.metadata(for: scenario.liveURL))
        XCTAssertEqual(scenario.installer.backupCount, 0)
        XCTAssertEqual(scenario.installer.restoreCount, 1)
    }
}

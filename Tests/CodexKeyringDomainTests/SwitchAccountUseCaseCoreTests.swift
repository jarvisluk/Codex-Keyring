import XCTest
@testable import CodexKeyringDomain

final class SwitchAccountUseCaseCoreTests: XCTestCase {
    func testSwitchAccountInstallsSnapshotBacksUpAndRestarts() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = accountRepository(
            accounts: [oldAccount, newAccount],
            activeAccountID: oldAccount.id
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let appController = MockAppController(outcome: .relaunched)

        let result = try await switchAccountUseCase(
            repository: repository,
            installer: installer,
            registry: registry,
            appController: appController
        )(accountID: newAccount.id, restartCodexApp: true)

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, newAccount.id)
        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "new")
        XCTAssertEqual(installer.backupCount, 1)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "new")
    }

    func testSwitchAccountReturnsSwitchedStateWhenCodexAppRestartFails() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = accountRepository(
            accounts: [oldAccount, newAccount],
            activeAccountID: oldAccount.id
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let appController = MockAppController(
            outcome: .relaunched,
            restartError: CodexKeyringError.codexAppRelaunchFailed(reason: "launch denied")
        )

        let result = try await switchAccountUseCase(
            repository: repository,
            installer: installer,
            registry: registry,
            appController: appController
        )(accountID: newAccount.id, restartCodexApp: true)

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, newAccount.id)
        XCTAssertEqual(result.state.activeAccountID, newAccount.id)
        XCTAssertNil(result.restartOutcome)
        XCTAssertEqual(result.restartFailureReason, "launch denied")
        XCTAssertEqual(installer.backupCount, 1)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "new")
    }

    func testSwitchAccountPreservesInstallerBackupFailureReason() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = accountRepository(
            accounts: [oldAccount, newAccount],
            activeAccountID: oldAccount.id
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(
            liveAuthFileURL: liveURL,
            registry: registry,
            backupError: CodexKeyringError.backupFailed(reason: "Live auth path is not a file")
        )

        do {
            _ = try await switchAccountUseCase(
                repository: repository,
                installer: installer,
                registry: registry,
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: false)
            XCTFail("Expected switch to fail when backup fails.")
        } catch CodexKeyringError.backupFailed(let reason) {
            XCTAssertEqual(reason, "Live auth path is not a file")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
    }
}

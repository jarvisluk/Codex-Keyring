import XCTest
@testable import CodexKeyringDomain

final class SwitchAccountUseCaseLiveAuthSyncTests: XCTestCase {
    func testSwitchAccountWritesRotatedTokenBackBeforeInstalling() async throws {
        let identifier = "user-A"
        let oldFingerprint = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v1",
            tokenExpiresAt: nil
        )
        let rotated = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v2",
            tokenExpiresAt: nil
        )
        let newMeta = metadata(email: "b@example.com", fingerprint: "fp-B")
        let accountA = account(id: UUID(), alias: "A", metadata: oldFingerprint)
        let accountB = account(id: UUID(), alias: "B", metadata: newMeta)

        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: rotated])
        let repository = accountRepository(
            accounts: [accountA, accountB],
            activeAccountID: accountA.id
        )
        registry.set(newMeta, for: repository.snapshotURL(named: accountB.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let appController = MockAppController(outcome: .relaunched)

        let result = try await switchAccountUseCase(
            repository: repository,
            installer: installer,
            registry: registry,
            appController: appController
        )(accountID: accountB.id, restartCodexApp: false)

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1, "Should re-snapshot account A before switching away")
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, accountA.id)
        XCTAssertEqual(repository.lastSnapshotWrite?.source, liveURL)
        XCTAssertEqual(manifest.accounts.first(where: { $0.id == accountA.id })?.fingerprint, "fp-A-v2")
        XCTAssertEqual(manifest.activeAccountID, accountB.id)
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "fp-B")
        XCTAssertEqual(installer.backupCount, 1)
    }

    func testSwitchAccountStopsWhenRotatedLiveAuthCannotBeSavedBack() async throws {
        let identifier = "user-A"
        let oldFingerprint = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v1",
            tokenExpiresAt: nil
        )
        let rotated = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v2",
            tokenExpiresAt: nil
        )
        let newMeta = metadata(email: "b@example.com", fingerprint: "fp-B")
        let accountA = account(id: UUID(), alias: "A", metadata: oldFingerprint)
        let accountB = account(id: UUID(), alias: "B", metadata: newMeta)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: rotated])
        let writeError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = accountRepository(
            accounts: [accountA, accountB],
            activeAccountID: accountA.id,
            writeError: writeError
        )
        registry.set(newMeta, for: repository.snapshotURL(named: accountB.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await switchAccountUseCase(
                repository: repository,
                installer: installer,
                registry: registry,
                appController: MockAppController(outcome: .relaunched)
            )(accountID: accountB.id, restartCodexApp: false)
            XCTFail("Expected switch to stop when current live auth cannot be preserved.")
        } catch CodexKeyringError.currentAuthSyncFailed(let reason) {
            XCTAssertTrue(reason.contains("disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, accountA.id)
        XCTAssertEqual(manifest.activeAccountID, accountA.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "fp-A-v2")
        XCTAssertEqual(installer.backupCount, 0)
    }
}

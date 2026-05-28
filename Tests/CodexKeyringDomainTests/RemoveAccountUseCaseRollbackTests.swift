import XCTest
@testable import CodexKeyringDomain

final class RemoveAccountUseCaseRollbackTests: XCTestCase {
    func testRemoveAccountRollsBackManifestWhenSnapshotDeleteFails() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "permission denied")
        let repository = accountRepository(
            accounts: [account],
            activeAccountID: account.id,
            deleteError: deleteError
        )

        do {
            _ = try await removeAccountUseCase(
                repository: repository,
                registry: registry,
                liveAuthFileURL: liveURL
            )(accountID: account.id)
            XCTFail("Expected removal to fail when snapshot deletion fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, deleteError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [account.id])
        XCTAssertEqual(manifest.activeAccountID, account.id)
        XCTAssertEqual(repository.saveCount, 2)
    }

    func testRemoveAccountRollsBackWhenSnapshotDeleteFailsDespiteUnconfirmedExistence() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "permission denied")
        let repository = accountRepository(
            accounts: [account],
            activeAccountID: account.id,
            deleteError: deleteError,
            snapshotExists: false
        )

        do {
            _ = try await removeAccountUseCase(
                repository: repository,
                registry: registry,
                liveAuthFileURL: liveURL
            )(accountID: account.id)
            XCTFail("Expected removal to fail when snapshot deletion fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, deleteError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [account.id])
        XCTAssertEqual(manifest.activeAccountID, account.id)
        XCTAssertEqual(repository.saveCount, 2)
        XCTAssertTrue(repository.deletedSnapshots.isEmpty)
    }

    func testRemoveAccountReportsWhenManifestRollbackFailsAfterSnapshotDeleteFails() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "permission denied")
        let rollbackError = CodexKeyringError.fileSystemFailure(reason: "rollback disk full")
        let repository = accountRepository(
            accounts: [account],
            activeAccountID: account.id,
            saveErrorsByAttempt: [2: rollbackError],
            deleteError: deleteError
        )

        do {
            _ = try await removeAccountUseCase(
                repository: repository,
                registry: registry,
                liveAuthFileURL: liveURL
            )(accountID: account.id)
            XCTFail("Expected removal to fail when snapshot delete and rollback both fail.")
        } catch CodexKeyringError.manifestRollbackFailed(let originalReason, let rollbackReason) {
            XCTAssertTrue(originalReason.contains("permission denied"))
            XCTAssertTrue(rollbackReason.contains("rollback disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertTrue(manifest.accounts.isEmpty)
        XCTAssertNil(manifest.activeAccountID)
        XCTAssertEqual(repository.saveCount, 1)
    }
}

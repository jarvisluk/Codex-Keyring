import XCTest
@testable import CodexKeyringDomain

final class AddAccountUseCaseUpdatePersistenceTests: XCTestCase {
    func testAddAccountUpdateDoesNotOverwriteSnapshotWhenManifestSaveFails() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = accountRepository(
            accounts: [saved],
            activeAccountID: saved.id,
            saveError: saveError
        )

        do {
            _ = try await addAccountUseCase(repository: repository, registry: registry)(
                sourceURL: importURL,
                requestedAlias: nil,
                activate: true
            )
            XCTFail("Expected update to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 0)
        XCTAssertEqual(manifest.accounts.first?.email, "old@example.com")
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "same")
    }

    func testAddAccountUpdateRollsBackManifestWhenSnapshotWriteFails() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let writeError = CodexKeyringError.fileSystemFailure(reason: "source vanished")
        let repository = accountRepository(
            accounts: [saved],
            activeAccountID: saved.id,
            writeError: writeError
        )

        do {
            _ = try await addAccountUseCase(repository: repository, registry: registry)(
                sourceURL: importURL,
                requestedAlias: nil,
                activate: true
            )
            XCTFail("Expected update to fail when snapshot write fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, writeError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.saveCount, 2)
        XCTAssertEqual(manifest.accounts.first?.email, "old@example.com")
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "same")
    }

    func testAddAccountUpdateReportsWhenManifestRollbackFailsAfterSnapshotWriteFails() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let writeError = CodexKeyringError.fileSystemFailure(reason: "source vanished")
        let rollbackError = CodexKeyringError.fileSystemFailure(reason: "rollback disk full")
        let repository = accountRepository(
            accounts: [saved],
            activeAccountID: saved.id,
            saveErrorsByAttempt: [2: rollbackError],
            writeError: writeError
        )

        do {
            _ = try await addAccountUseCase(repository: repository, registry: registry)(
                sourceURL: importURL,
                requestedAlias: nil,
                activate: true
            )
            XCTFail("Expected update to fail when snapshot write and rollback both fail.")
        } catch CodexKeyringError.manifestRollbackFailed(let originalReason, let rollbackReason) {
            XCTAssertTrue(originalReason.contains("source vanished"))
            XCTAssertTrue(rollbackReason.contains("rollback disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(manifest.accounts.first?.email, "new@example.com")
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "same")
    }
}

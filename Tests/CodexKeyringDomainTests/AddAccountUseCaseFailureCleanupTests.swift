import XCTest
@testable import CodexKeyringDomain

final class AddAccountUseCaseFailureCleanupTests: XCTestCase {
    func testAddAccountDeletesNewSnapshotWhenManifestSaveFails() async throws {
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: new])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = accountRepository(saveError: saveError)

        do {
            _ = try await addAccountUseCase(repository: repository, registry: registry)(
                sourceURL: importURL,
                requestedAlias: "new",
                activate: true
            )
            XCTFail("Expected add account to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let writtenID = try XCTUnwrap(repository.lastSnapshotWrite?.accountID)
        XCTAssertEqual(repository.deletedSnapshots, ["\(writtenID.uuidString).auth.json"])
        let manifest = try await repository.load()
        XCTAssertTrue(manifest.accounts.isEmpty)
    }

    func testAddAccountCleansWrittenSnapshotWhenExistenceCheckCannotConfirmIt() async throws {
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: new])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = accountRepository(
            saveError: saveError,
            snapshotExists: false
        )

        do {
            _ = try await addAccountUseCase(repository: repository, registry: registry)(
                sourceURL: importURL,
                requestedAlias: "new",
                activate: true
            )
            XCTFail("Expected add account to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let writtenID = try XCTUnwrap(repository.lastSnapshotWrite?.accountID)
        XCTAssertEqual(repository.deletedSnapshots, ["\(writtenID.uuidString).auth.json"])
    }

    func testAddAccountReportsWhenNewSnapshotCleanupFailsAfterManifestSaveFails() async throws {
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: new])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "delete denied")
        let repository = accountRepository(
            saveError: saveError,
            deleteError: deleteError
        )

        do {
            _ = try await addAccountUseCase(repository: repository, registry: registry)(
                sourceURL: importURL,
                requestedAlias: "new",
                activate: true
            )
            XCTFail("Expected add account to report snapshot cleanup failure.")
        } catch CodexKeyringError.snapshotCleanupFailed(let originalReason, let cleanupReason, let snapshotFileName) {
            XCTAssertTrue(originalReason.contains("disk full"))
            XCTAssertTrue(cleanupReason.contains("delete denied"))
            XCTAssertEqual(snapshotFileName, "\(try XCTUnwrap(repository.lastSnapshotWrite?.accountID).uuidString).auth.json")
            XCTAssertFalse(
                CodexKeyringError.snapshotCleanupFailed(
                    originalReason: originalReason,
                    cleanupReason: cleanupReason,
                    snapshotFileName: snapshotFileName
                ).localizedDescription.contains(snapshotFileName)
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertTrue(manifest.accounts.isEmpty)
        XCTAssertTrue(repository.deletedSnapshots.isEmpty)
    }
}

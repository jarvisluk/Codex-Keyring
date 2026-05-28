import XCTest
@testable import CodexKeyringDomain

final class RemoveAccountUseCaseFailureTests: XCTestCase {
    func testRemoveAccountFailsWhenLiveAuthIsUnreadableBeforeMutatingManifest() async throws {
        let removedMeta = metadata(email: "old@example.com", fingerprint: "old")
        let remainingMeta = metadata(email: "current@example.com", fingerprint: "current")
        let removedAccount = account(id: UUID(), alias: "old", metadata: removedMeta)
        let remainingAccount = account(id: UUID(), alias: "current", metadata: remainingMeta)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: remainingMeta])
        let repository = accountRepository(
            accounts: [removedAccount, remainingAccount],
            activeAccountID: removedAccount.id
        )

        do {
            _ = try await removeAccountUseCase(
                repository: repository,
                registry: registry,
                liveAuthFileURL: liveURL,
                authReader: URLFailingAuthReader(
                    registry: registry,
                    failingURL: liveURL,
                    error: CodexKeyringError.authFileUnreadable
                )
            )(accountID: removedAccount.id)
            XCTFail("Expected removal to fail while live auth is unreadable.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [removedAccount.id, remainingAccount.id])
        XCTAssertEqual(manifest.activeAccountID, removedAccount.id)
        XCTAssertEqual(repository.saveCount, 0)
        XCTAssertTrue(repository.deletedSnapshots.isEmpty)
    }

    func testRemoveAccountDoesNotDeleteSnapshotWhenManifestSaveFails() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = accountRepository(
            accounts: [account],
            activeAccountID: account.id,
            saveError: saveError
        )

        do {
            _ = try await removeAccountUseCase(
                repository: repository,
                registry: registry,
                liveAuthFileURL: liveURL
            )(accountID: account.id)
            XCTFail("Expected removal to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [account.id])
        XCTAssertEqual(repository.deletedSnapshots, [])
    }
}

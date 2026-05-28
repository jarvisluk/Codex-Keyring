import XCTest
@testable import CodexKeyringDomain

final class RenameAccountUseCaseTests: XCTestCase {
    func testRenameAccountSkipsSaveWhenAliasIsUnchangedAfterCleaning() async throws {
        let original = metadata(email: "primary@example.com", fingerprint: "primary")
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: original])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await renameAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(accountID: saved.id, newAlias: "  primary\n")

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertFalse(result.didRename)
        XCTAssertEqual(result.newAlias, "primary")
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "primary")
        XCTAssertEqual(repository.saveCount, 0)
        XCTAssertEqual(updated.alias, "primary")
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 1))
    }

    func testRenameAccountCanClearAliasAndSortsByDisplayNameFallback() async throws {
        let source = metadata(email: "zeta@example.com", fingerprint: "zeta")
        let other = metadata(email: "alpha@example.com", fingerprint: "alpha")
        let accountA = account(id: UUID(), alias: "zeta", metadata: source)
        let accountB = account(id: UUID(), alias: "alpha", metadata: other)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: source])
        let repository = accountRepository(
            accounts: [accountA, accountB],
            activeAccountID: accountA.id
        )

        let result = try await renameAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(accountID: accountA.id, newAlias: "  ")

        let manifest = try await repository.load()
        let renamed = try XCTUnwrap(manifest.accounts.first { $0.id == accountA.id })
        XCTAssertTrue(result.didRename)
        XCTAssertEqual(result.newAlias, "")
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(renamed.alias, "")
        XCTAssertEqual(renamed.displayName, "zeta@example.com")
        XCTAssertEqual(renamed.updatedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(manifest.accounts.map(\.displayName), ["alpha", "zeta@example.com"])
    }

    func testRenameAccountUniquifiesChangedAliasAndUpdatesTimestamp() async throws {
        let source = metadata(email: "work@example.com", fingerprint: "work")
        let other = metadata(email: "personal@example.com", fingerprint: "personal")
        let accountA = account(id: UUID(), alias: "work", metadata: source)
        let accountB = account(id: UUID(), alias: "personal", metadata: other)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: source])
        let repository = accountRepository(
            accounts: [accountA, accountB],
            activeAccountID: accountA.id
        )

        let result = try await renameAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(accountID: accountA.id, newAlias: " personal ")

        let manifest = try await repository.load()
        let renamed = try XCTUnwrap(manifest.accounts.first { $0.id == accountA.id })
        let untouched = try XCTUnwrap(manifest.accounts.first { $0.id == accountB.id })
        XCTAssertTrue(result.didRename)
        XCTAssertEqual(result.newAlias, "personal-2")
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(manifest.accounts.map(\.alias), ["personal", "personal-2"])
        XCTAssertEqual(renamed.updatedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(untouched.updatedAt, Date(timeIntervalSince1970: 1))
    }
}

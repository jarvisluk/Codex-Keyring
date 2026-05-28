import XCTest
@testable import CodexKeyringDomain

final class AddAccountUseCaseUpdateMetadataTests: XCTestCase {
    func testAddAccountUpdatePreservesAliasWhenNoAliasIsRequested() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "my custom name", metadata: original)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await addAccountUseCase(repository: repository, registry: registry)(
            sourceURL: importURL,
            requestedAlias: nil,
            activate: true
        )

        let manifest = try await repository.load()
        let account = try XCTUnwrap(manifest.accounts.first)
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(result.savedAlias, "my custom name")
        XCTAssertEqual(account.alias, "my custom name")
        XCTAssertEqual(account.email, "new@example.com")
        XCTAssertEqual(account.updatedAt, Date(timeIntervalSince1970: 500))
    }

    func testAddAccountUpdateUniquifiesAliasAgainstOtherAccounts() async throws {
        let original = metadata(email: "work@example.com", fingerprint: "work")
        let updated = metadata(email: "updated@example.com", fingerprint: "work")
        let other = metadata(email: "personal@example.com", fingerprint: "personal")
        let accountA = account(id: UUID(), alias: "work", metadata: original)
        let accountB = account(id: UUID(), alias: "personal", metadata: other)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let repository = accountRepository(
            accounts: [accountA, accountB],
            activeAccountID: accountA.id
        )

        let result = try await addAccountUseCase(repository: repository, registry: registry)(
            sourceURL: importURL,
            requestedAlias: " personal ",
            activate: true
        )

        let manifest = try await repository.load()
        let renamed = try XCTUnwrap(manifest.accounts.first { $0.id == accountA.id })
        let untouched = try XCTUnwrap(manifest.accounts.first { $0.id == accountB.id })
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(result.savedAlias, "personal-2")
        XCTAssertEqual(renamed.alias, "personal-2")
        XCTAssertEqual(renamed.email, "updated@example.com")
        XCTAssertEqual(untouched.alias, "personal")
        XCTAssertEqual(manifest.accounts.map(\.alias), ["personal", "personal-2"])
    }

    func testAddAccountUpdateDoesNotOverwriteUsefulMetadataWithPlaceholders() async throws {
        let original = AuthMetadata(
            email: "known@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let sparse = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: nil
        )
        let saved = account(id: UUID(), alias: "known", metadata: original)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: sparse])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await addAccountUseCase(repository: repository, registry: registry)(
            sourceURL: importURL,
            requestedAlias: nil,
            activate: true
        )

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(updated.email, "known@example.com")
        XCTAssertEqual(updated.plan, "plus")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 500))
    }
}

import CodexKeyringDomain
import XCTest
@testable import CodexKeyringCLI

final class AccountSelectorTests: XCTestCase {
    func testResolvesByExactAlias() throws {
        let work = account(alias: "Work", email: "work@example.com")
        let personal = account(alias: "Personal", email: "me@example.com")

        let resolved = try AccountSelector().resolve("work", accounts: [personal, work])

        XCTAssertEqual(resolved.id, work.id)
    }

    func testResolvesByUUIDPrefix() throws {
        let work = account(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            alias: "Work"
        )

        let resolved = try AccountSelector().resolve("12345678", accounts: [work])

        XCTAssertEqual(resolved.id, work.id)
    }

    func testAmbiguousExactEmailDoesNotGuess() throws {
        let first = account(alias: "First", email: "shared@example.com")
        let second = account(alias: "Second", email: "shared@example.com")

        XCTAssertThrowsError(
            try AccountSelector().resolve("shared@example.com", accounts: [first, second])
        ) { error in
            guard case AccountSelectorError.ambiguous = error else {
                return XCTFail("Expected ambiguous account selector error, got \(error).")
            }
        }
    }

    func testJSONAccountOutputDoesNotExposeSnapshotOrAccountIdentifier() throws {
        let saved = account(
            alias: "Work",
            email: "work@example.com",
            accountIdentifier: "acct-secret",
            snapshotFileName: "snapshot-secret.json"
        )

        let output = try CLIFormat.json(CLIAccountDTO(account: saved, active: true))

        XCTAssertFalse(output.contains("snapshot-secret"))
        XCTAssertFalse(output.contains("acct-secret"))
        XCTAssertTrue(output.contains("work@example.com"))
    }

    private func account(
        id: UUID = UUID(),
        alias: String,
        email: String = "user@example.com",
        accountIdentifier: String = "acct-user",
        snapshotFileName: String = "snapshot.json"
    ) -> CodexAccount {
        CodexAccount(
            id: id,
            alias: alias,
            email: email,
            plan: "Plus",
            authMode: "chatgpt",
            accountIdentifier: accountIdentifier,
            snapshotFileName: snapshotFileName,
            fingerprint: "abcdef1234567890",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            tokenExpiresAt: nil
        )
    }
}

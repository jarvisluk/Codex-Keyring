import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class MenuBarAccountPresentationTests: XCTestCase {
    func testTitleUsesTrimmedAlias() {
        let presentation = MenuBarAccountPresentation(account: makeAccount(
            alias: "  work  ",
            email: "person@example.com"
        ))

        XCTAssertEqual(presentation.title, "work")
    }

    func testTitleFallsBackToEmailWhenAliasIsBlank() {
        let presentation = MenuBarAccountPresentation(account: makeAccount(
            alias: "  ",
            email: "person@example.com"
        ))

        XCTAssertEqual(presentation.title, "person@example.com")
    }

    func testTitleUsesUnknownEmailFallbackWhenAliasAndEmailAreBlank() {
        let presentation = MenuBarAccountPresentation(account: makeAccount(
            alias: "  ",
            email: "\n"
        ))

        XCTAssertEqual(presentation.title, "Unknown email")
    }

    private func makeAccount(alias: String, email: String) -> CodexAccount {
        CodexAccount(
            id: UUID(),
            alias: alias,
            email: email,
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            snapshotFileName: "person.auth.json",
            fingerprint: "fingerprint",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
    }
}

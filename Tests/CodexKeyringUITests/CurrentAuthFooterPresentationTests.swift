import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class CurrentAuthFooterPresentationTests: XCTestCase {
    func testCurrentAuthTitleTrimsMetadataEmail() {
        let presentation = CurrentAuthFooterPresentation(
            metadata: makeMetadata(email: "  person@example.com  "),
            savedAccount: nil,
            authPath: "/tmp/auth.json"
        )

        XCTAssertEqual(presentation.title, "person@example.com")
        XCTAssertEqual(presentation.subtitle, "Not in credentials")
        XCTAssertEqual(presentation.contextMenuTitle, "Add to Credentials")
        XCTAssertEqual(
            presentation.accessibilitySummary,
            "Current Codex Auth: person@example.com. Not in credentials."
        )
    }

    func testCurrentAuthTitleUsesFallbackForBlankMetadataEmail() {
        let presentation = CurrentAuthFooterPresentation(
            metadata: makeMetadata(email: "\n\t"),
            savedAccount: nil,
            authPath: "/tmp/auth.json"
        )

        XCTAssertEqual(presentation.title, "Unknown email")
        XCTAssertEqual(presentation.subtitle, "Not in credentials")
    }

    func testSavedCurrentAuthUsesSavedAccountDisplayName() {
        let presentation = CurrentAuthFooterPresentation(
            metadata: makeMetadata(email: "person@example.com"),
            savedAccount: makeAccount(alias: "  work  ", email: "person@example.com"),
            authPath: "/tmp/auth.json"
        )

        XCTAssertEqual(presentation.title, "person@example.com")
        XCTAssertEqual(presentation.subtitle, "Saved as work")
        XCTAssertEqual(presentation.contextMenuTitle, "Already in Credentials")
    }

    func testUnreadableAuthUsesAuthPath() {
        let presentation = CurrentAuthFooterPresentation(
            metadata: nil,
            savedAccount: nil,
            authPath: "/tmp/auth.json"
        )

        XCTAssertEqual(presentation.title, "No readable auth.json")
        XCTAssertEqual(presentation.subtitle, "/tmp/auth.json")
        XCTAssertEqual(presentation.contextMenuTitle, "Add to Credentials")
    }

    private func makeMetadata(email: String) -> AuthMetadata {
        AuthMetadata(
            email: email,
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "fingerprint",
            tokenExpiresAt: nil
        )
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

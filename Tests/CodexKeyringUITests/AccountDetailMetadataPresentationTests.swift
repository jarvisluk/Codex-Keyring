import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountDetailMetadataPresentationTests: XCTestCase {
    func testPresentationTrimsVisibleMetadata() {
        let presentation = AccountDetailMetadataPresentation(account: makeAccount(
            authMode: " chatgpt ",
            plan: "\nplus\t",
            accountIdentifier: " account-123 ",
            fingerprint: "  abcdef1234567890  "
        ))

        XCTAssertEqual(presentation.authMode, "chatgpt")
        XCTAssertEqual(presentation.plan, "plus")
        XCTAssertEqual(presentation.accountIdentifier, "account-123")
        XCTAssertEqual(presentation.fingerprint, "abcdef1234")
    }

    func testPresentationUsesFallbacksForBlankMetadata() {
        let presentation = AccountDetailMetadataPresentation(account: makeAccount(
            authMode: " ",
            plan: "\n",
            accountIdentifier: "\t",
            fingerprint: "  "
        ))

        XCTAssertEqual(presentation.authMode, "Unknown")
        XCTAssertEqual(presentation.plan, "Unknown")
        XCTAssertEqual(presentation.accountIdentifier, "Unknown")
        XCTAssertEqual(presentation.fingerprint, "Unknown")
    }

    private func makeAccount(
        authMode: String,
        plan: String,
        accountIdentifier: String,
        fingerprint: String
    ) -> CodexAccount {
        CodexAccount(
            id: UUID(),
            alias: "work",
            email: "person@example.com",
            plan: plan,
            authMode: authMode,
            accountIdentifier: accountIdentifier,
            snapshotFileName: "person.auth.json",
            fingerprint: fingerprint,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
    }
}

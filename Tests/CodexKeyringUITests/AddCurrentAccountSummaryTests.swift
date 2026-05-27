import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AddCurrentAccountSummaryTests: XCTestCase {
    func testSummaryTrimsVisibleMetadata() {
        let summary = AddCurrentAccountSummary(metadata: AuthMetadata(
            email: "  person@example.com  ",
            plan: "\nplus\t",
            authMode: " chatgpt ",
            accountIdentifier: "account-123",
            fingerprint: "  abcdef1234567890  ",
            tokenExpiresAt: nil
        ))

        XCTAssertEqual(summary.email, "person@example.com")
        XCTAssertEqual(summary.plan, "plus")
        XCTAssertEqual(summary.authMode, "chatgpt")
        XCTAssertEqual(summary.fingerprint, "abcdef1234")
    }

    func testSummaryUsesFallbacksForBlankMetadata() {
        let summary = AddCurrentAccountSummary(metadata: AuthMetadata(
            email: "  ",
            plan: "\n",
            authMode: "\t",
            accountIdentifier: "",
            fingerprint: " ",
            tokenExpiresAt: nil
        ))

        XCTAssertEqual(summary.email, "Unknown email")
        XCTAssertEqual(summary.plan, "Unknown")
        XCTAssertEqual(summary.authMode, "Unknown")
        XCTAssertEqual(summary.fingerprint, "Unknown")
    }
}

import XCTest
@testable import CodexKeyringUI

final class AccountSensitiveTextTests: XCTestCase {
    func testAccountSensitiveTextMasksEmailsAndIdentifiers() {
        XCTAssertEqual(
            AccountSensitiveText.display("person@example.com", revealed: false),
            "pe****@e****.com"
        )
        XCTAssertEqual(
            AccountSensitiveText.display("acct-123", revealed: false),
            "ac****23"
        )
        XCTAssertEqual(
            AccountSensitiveText.display("abcdef1234", revealed: false),
            "abcd****1234"
        )
    }

    func testAccountSensitiveTextLeavesFallbacksReadable() {
        XCTAssertEqual(
            AccountSensitiveText.display("Unknown email", revealed: false),
            "Unknown email"
        )
        XCTAssertEqual(
            AccountSensitiveText.display("No readable auth.json", revealed: false),
            "No readable auth.json"
        )
    }

    func testAccountSensitiveTextRevealsValuesWhenEnabled() {
        XCTAssertEqual(
            AccountSensitiveText.display("person@example.com", revealed: true),
            "person@example.com"
        )
    }
}

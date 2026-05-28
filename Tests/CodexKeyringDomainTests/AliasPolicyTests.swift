import XCTest
@testable import CodexKeyringDomain

final class AliasPolicyTests: XCTestCase {
    func testCleanUsesFallbackWhenTrimmedAliasIsBlank() {
        let policy = AliasPolicy()

        XCTAssertEqual(policy.clean("  ", fallback: "fallback"), "fallback")
        XCTAssertEqual(policy.clean("  ", fallback: "  "), "account")
    }

    func testCleanAllowingEmptyPreservesIntentionalBlankAlias() {
        let policy = AliasPolicy()

        XCTAssertEqual(policy.cleanAllowingEmpty("  "), "")
        XCTAssertEqual(policy.cleanAllowingEmpty("  display name\n"), "display name")
    }

    func testUniquifiedComparesAliasesCaseInsensitively() {
        let policy = AliasPolicy()
        let first = account(
            id: UUID(),
            alias: "Work",
            metadata: metadata(email: "work@example.com", fingerprint: "work")
        )
        let second = account(
            id: UUID(),
            alias: "Work-2",
            metadata: metadata(email: "second@example.com", fingerprint: "second")
        )

        XCTAssertEqual(
            policy.uniquified("Work", existingAliases: ["work", "work-2"]),
            "Work-3"
        )
        XCTAssertEqual(policy.uniquified("Work", among: [first, second]), "Work-3")
        XCTAssertEqual(policy.renameAlias(" work ", for: first, among: [first, second]), "work")
        XCTAssertEqual(policy.renameAlias("  ", for: first, among: [first, second]), "")
    }

    func testSuggestedAliasPrefersEmailLocalPart() {
        let policy = AliasPolicy()

        XCTAssertEqual(
            policy.suggested(for: metadata(email: "", fingerprint: "empty")),
            "account"
        )
        XCTAssertEqual(
            policy.suggested(for: metadata(email: "  person@example.com  ", fingerprint: "spaced")),
            "person"
        )
        XCTAssertEqual(
            policy.suggested(for: metadata(email: "  ", fingerprint: "blank")),
            "account"
        )
    }
}

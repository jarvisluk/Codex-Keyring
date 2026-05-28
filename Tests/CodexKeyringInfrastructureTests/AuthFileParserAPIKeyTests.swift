import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class AuthFileParserAPIKeyTests: XCTestCase {
    func testParsesAPIKeyAuthMetadata() throws {
        let url = try writeAuthParserJSON([
            "OPENAI_API_KEY": "sk-test"
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "API key account")
        XCTAssertEqual(metadata.plan, "API key")
        XCTAssertEqual(metadata.authMode, "api-key")
        XCTAssertEqual(metadata.accountIdentifier, "api-key")
    }

    func testAPIKeyAuthUsesAPIKeyIdentifierEvenWithUnexpectedAuthMode() throws {
        let url = try writeAuthParserJSON([
            "auth_mode": "chatgpt",
            "OPENAI_API_KEY": "sk-test"
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "API key account")
        XCTAssertEqual(metadata.plan, "API key")
        XCTAssertEqual(metadata.accountIdentifier, AuthMetadata.apiKeyAccountIdentifier)
    }
}

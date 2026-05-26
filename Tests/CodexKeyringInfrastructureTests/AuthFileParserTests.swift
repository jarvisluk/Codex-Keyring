import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class AuthFileParserTests: XCTestCase {
    func testParsesChatGPTAuthMetadataFromIDToken() throws {
        let expiry: TimeInterval = 1_893_456_000
        let token = makeJWT(payload: [
            "email": "person@example.com",
            "exp": expiry,
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": "plus"
            ]
        ])
        let url = try writeAuthJSON([
            "auth_mode": "chatgpt",
            "tokens": [
                "account_id": "account-123",
                "id_token": token
            ]
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "person@example.com")
        XCTAssertEqual(metadata.plan, "plus")
        XCTAssertEqual(metadata.authMode, "chatgpt")
        XCTAssertEqual(metadata.accountIdentifier, "account-123")
        XCTAssertEqual(metadata.tokenExpiresAt, Date(timeIntervalSince1970: expiry))
        XCTAssertFalse(metadata.fingerprint.isEmpty)
    }

    func testParsesAPIKeyAuthMetadata() throws {
        let url = try writeAuthJSON([
            "OPENAI_API_KEY": "sk-test"
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "API key account")
        XCTAssertEqual(metadata.plan, "API key")
        XCTAssertEqual(metadata.authMode, "api-key")
        XCTAssertEqual(metadata.accountIdentifier, "api-key")
    }

    func testRejectsEmptyTokensObject() throws {
        let url = try writeAuthJSON([
            "tokens": [:]
        ])

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: url)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .unsupportedAuthShape)
        }
    }
}

private func writeAuthJSON(_ object: [String: Any]) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexKeyringTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("auth.json")
    let data = try JSONSerialization.data(withJSONObject: object)
    try data.write(to: url)
    return url
}

private func makeJWT(payload: [String: Any]) -> String {
    let header = ["alg": "none", "typ": "JWT"]
    return [
        base64URLEncodedJSON(header),
        base64URLEncodedJSON(payload),
        "signature"
    ].joined(separator: ".")
}

private func base64URLEncodedJSON(_ object: [String: Any]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: object)
    return data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

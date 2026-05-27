import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class AuthFileParserTests: XCTestCase {
    func testParsesChatGPTAuthMetadataFromIDToken() throws {
        let expiry: TimeInterval = 1_893_456_000
        let token = try makeJWT(payload: [
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

    func testParsesChatGPTAuthMetadataFromAccessTokenWhenIDTokenIsMissing() throws {
        let expiry: TimeInterval = 1_893_459_600
        let token = try makeJWT(payload: [
            "exp": expiry,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-from-access",
                "chatgpt_plan_type": "business"
            ],
            "https://api.openai.com/profile": [
                "email": "access@example.com"
            ]
        ])
        let url = try writeAuthJSON([
            "auth_mode": "chatgpt",
            "tokens": [
                "access_token": token
            ]
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "access@example.com")
        XCTAssertEqual(metadata.plan, "business")
        XCTAssertEqual(metadata.accountIdentifier, "account-from-access")
        XCTAssertEqual(metadata.tokenExpiresAt, Date(timeIntervalSince1970: expiry))
    }

    func testParsesRefreshTokenOnlyChatGPTAuthMetadata() throws {
        let url = try writeAuthJSON([
            "auth_mode": "chatgpt",
            "tokens": [
                "refresh_token": "refresh-token"
            ]
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "Unknown account")
        XCTAssertEqual(metadata.plan, "chatgpt")
        XCTAssertEqual(metadata.authMode, "chatgpt")
        XCTAssertEqual(metadata.accountIdentifier, AuthMetadata.unknownChatGPTAccountIdentifier)
        XCTAssertNil(metadata.tokenExpiresAt)
        XCTAssertFalse(metadata.fingerprint.isEmpty)
    }

    func testFallsBackToAccessTokenEmailWhenIDTokenProfileIsSparse() throws {
        let idToken = try makeJWT(payload: [
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": "plus"
            ]
        ])
        let accessToken = try makeJWT(payload: [
            "https://api.openai.com/profile": [
                "email": "access-profile@example.com"
            ]
        ])
        let url = try writeAuthJSON([
            "auth_mode": "chatgpt",
            "tokens": [
                "id_token": idToken,
                "access_token": accessToken,
                "account_id": "account-123"
            ]
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "access-profile@example.com")
        XCTAssertEqual(metadata.plan, "plus")
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

    func testAPIKeyAuthUsesAPIKeyIdentifierEvenWithUnexpectedAuthMode() throws {
        let url = try writeAuthJSON([
            "auth_mode": "chatgpt",
            "OPENAI_API_KEY": "sk-test"
        ])

        let metadata = try AuthFileParser.parseAuthFile(at: url)

        XCTAssertEqual(metadata.email, "API key account")
        XCTAssertEqual(metadata.plan, "API key")
        XCTAssertEqual(metadata.accountIdentifier, AuthMetadata.apiKeyAccountIdentifier)
    }

    func testAsyncReadRunsOnConfiguredIOQueue() async throws {
        let url = try writeAuthJSON([
            "OPENAI_API_KEY": "sk-test"
        ])
        let ioQueue = DispatchQueue(label: "tests.AuthFileParser.suspended")
        let releaseQueue = blockSerialQueue(ioQueue, description: "auth parser io queue")
        var didReleaseQueue = false
        defer {
            if !didReleaseQueue {
                releaseQueue()
            }
        }
        let parser = AuthFileParser(ioQueue: ioQueue)

        let readStarted = expectation(description: "async auth read started")
        let readTask = Task {
            readStarted.fulfill()
            return try await parser.read(from: url)
        }
        await fulfillment(of: [readStarted], timeout: 1)
        let replacementToken = try makeJWT(payload: [
            "email": "queued@example.com"
        ])
        let replacement = try JSONSerialization.data(withJSONObject: [
            "auth_mode": "chatgpt",
            "tokens": [
                "id_token": replacementToken
            ]
        ])
        try replacement.write(to: url)

        releaseQueue()
        didReleaseQueue = true
        let metadata = try await readTask.value
        XCTAssertEqual(metadata.email, "queued@example.com")
    }

    func testRejectsEmptyTokensObject() throws {
        let url = try writeAuthJSON([
            "tokens": [:]
        ])

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: url)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .unsupportedAuthShape)
        }
    }

    func testRejectsAccountIdentifierWithoutCredential() throws {
        let url = try writeAuthJSON([
            "auth_mode": "chatgpt",
            "tokens": [
                "account_id": "account-123"
            ]
        ])

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: url)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .unsupportedAuthShape)
        }
    }

    func testRejectsWhitespaceOnlyAuthFields() throws {
        let url = try writeAuthJSON([
            "OPENAI_API_KEY": " \n\t ",
            "tokens": [
                "account_id": " ",
                "id_token": "\n",
                "access_token": "\t",
                "refresh_token": "   "
            ]
        ])

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: url)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .unsupportedAuthShape)
        }
    }

    func testMissingAuthFileThrowsDomainErrorWithURL() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).json")

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: url)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .authFileMissing(url))
        }
    }

    func testUnreadableAuthFileThrowsDomainUnreadableError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuthFileParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: directory)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .authFileUnreadable)
        }
    }

    func testInvalidJSONThrowsDomainUnreadableError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuthFileParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("auth.json")
        try Data("{".utf8).write(to: url)

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: url)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .authFileUnreadable)
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

private func makeJWT(payload: [String: Any]) throws -> String {
    let header = ["alg": "none", "typ": "JWT"]
    return [
        try base64URLEncodedJSON(header),
        try base64URLEncodedJSON(payload),
        "signature"
    ].joined(separator: ".")
}

private func base64URLEncodedJSON(_ object: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object)
    return data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

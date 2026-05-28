import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class AuthFileParserFailureTests: XCTestCase {
    func testRejectsEmptyTokensObject() throws {
        let url = try writeAuthParserJSON([
            "tokens": [:]
        ])

        XCTAssertThrowsError(try AuthFileParser.parseAuthFile(at: url)) { error in
            XCTAssertEqual(error as? CodexKeyringError, .unsupportedAuthShape)
        }
    }

    func testRejectsAccountIdentifierWithoutCredential() throws {
        let url = try writeAuthParserJSON([
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
        let url = try writeAuthParserJSON([
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

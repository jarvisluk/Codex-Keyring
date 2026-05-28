import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class AuthFileParserChatGPTTests: XCTestCase {
    func testParsesChatGPTAuthMetadataFromIDToken() throws {
        let expiry: TimeInterval = 1_893_456_000
        let token = try makeAuthParserJWT(payload: [
            "email": "person@example.com",
            "exp": expiry,
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": "plus"
            ]
        ])
        let url = try writeAuthParserJSON([
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
        let token = try makeAuthParserJWT(payload: [
            "exp": expiry,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-from-access",
                "chatgpt_plan_type": "business"
            ],
            "https://api.openai.com/profile": [
                "email": "access@example.com"
            ]
        ])
        let url = try writeAuthParserJSON([
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
        let url = try writeAuthParserJSON([
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
        let idToken = try makeAuthParserJWT(payload: [
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": "plus"
            ]
        ])
        let accessToken = try makeAuthParserJWT(payload: [
            "https://api.openai.com/profile": [
                "email": "access-profile@example.com"
            ]
        ])
        let url = try writeAuthParserJSON([
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
}

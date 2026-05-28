import XCTest
@testable import CodexKeyringInfrastructure

final class ChatGPTOAuthLoginServiceTokenExchangeSanitizationTests: ChatGPTOAuthLoginServiceTestCase {
    func testTokenExchangeFailureSummarizesOAuthErrorWithoutEchoingTokenFields() async throws {
        let fixture = try makeOAuthLoginServiceFixture()

        OAuthLoginURLProtocol.setHandler { _ in
            try .json(
                [
                    "error": "invalid_grant",
                    "error_description": "expired authorization code",
                    "access_token": "secret-access-token"
                ],
                statusCode: 400
            )
        }

        do {
            try await completeOAuthLogin(fixture.service)
            XCTFail("Expected token exchange failure")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("OAuth token endpoint returned HTTP 400"))
            XCTAssertTrue(message.contains("invalid_grant"))
            XCTAssertTrue(message.contains("expired authorization code"))
            XCTAssertFalse(message.contains("secret-access-token"))
            XCTAssertFalse(message.contains("access_token"))
            XCTAssertFalse(message.contains("Token exchange failed: Codex login failed"))
        }
    }

    func testTokenExchangeFailureDoesNotEchoOAuthClientSecrets() async throws {
        let fixture = try makeOAuthLoginServiceFixture()

        OAuthLoginURLProtocol.setHandler { _ in
            try .json(
                [
                    "error": "invalid_grant",
                    "error_description": "client_secret=top-secret"
                ],
                statusCode: 400
            )
        }

        do {
            try await completeOAuthLogin(fixture.service)
            XCTFail("Expected token exchange failure")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("OAuth token endpoint returned HTTP 400"))
            XCTAssertTrue(message.contains("invalid_grant"))
            XCTAssertFalse(message.contains("client_secret"))
            XCTAssertFalse(message.contains("top-secret"))
        }
    }

    func testTokenExchangeFailureDoesNotEchoAuthorizationParameters() async throws {
        let fixture = try makeOAuthLoginServiceFixture()

        OAuthLoginURLProtocol.setHandler { _ in
            try .json(
                [
                    "error": "invalid_grant",
                    "error_description": "code=callback-code&code_challenge=secret-challenge&state=secret-state"
                ],
                statusCode: 400
            )
        }

        do {
            try await completeOAuthLogin(fixture.service)
            XCTFail("Expected token exchange failure")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("OAuth token endpoint returned HTTP 400"))
            XCTAssertTrue(message.contains("invalid_grant"))
            XCTAssertFalse(message.contains("callback-code"))
            XCTAssertFalse(message.contains("secret-challenge"))
            XCTAssertFalse(message.contains("secret-state"))
            XCTAssertFalse(message.contains("code="))
            XCTAssertFalse(message.contains("code_challenge"))
            XCTAssertFalse(message.contains("state="))
        }
    }
}

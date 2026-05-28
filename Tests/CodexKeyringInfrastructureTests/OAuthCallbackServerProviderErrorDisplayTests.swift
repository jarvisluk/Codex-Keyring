import XCTest
@testable import CodexKeyringInfrastructure

final class OAuthCallbackServerProviderErrorDisplayTests: OAuthCallbackServerTestCase {
    func testProviderErrorDescriptionIsNotEchoedWhenItContainsTokenFields() async throws {
        let result = try await callbackFailure(
            query: "error=access_denied&error_description=access_token%3Dsecret"
        )

        XCTAssertTrue(result.body.contains("OAuth provider returned error access_denied."))
        XCTAssertFalse(result.body.contains("access_token"))
        XCTAssertFalse(result.body.contains("secret"))

        guard case OAuthCallbackServer.ServerError.oauthError(let code, let description) = result.error else {
            return XCTFail("Unexpected error: \(result.error)")
        }
        XCTAssertEqual(code, "access_denied")
        XCTAssertEqual(description, "access_token=secret")
        XCTAssertEqual(
            OAuthCallbackServer.ServerError.oauthError(
                code: code,
                description: description
            ).localizedDescription,
            "OAuth provider returned error access_denied."
        )
    }

    func testProviderErrorCodeIsSanitizedBeforeDisplay() async throws {
        let result = try await callbackFailure(
            query: "error=access_token%3Dsecret"
        )

        XCTAssertTrue(result.body.contains("OAuth provider returned an OAuth error."))
        XCTAssertFalse(result.body.contains("access_token"))
        XCTAssertFalse(result.body.contains("secret"))

        guard case OAuthCallbackServer.ServerError.oauthError(let code, let description) = result.error else {
            return XCTFail("Unexpected error: \(result.error)")
        }
        XCTAssertEqual(code, "access_token=secret")
        XCTAssertNil(description)
        XCTAssertEqual(
            OAuthCallbackServer.ServerError.oauthError(
                code: code,
                description: description
            ).localizedDescription,
            "OAuth provider returned an OAuth error."
        )
    }

    func testProviderErrorDescriptionDoesNotEchoOAuthClientSecrets() async throws {
        let result = try await callbackFailure(
            query: "error=invalid_request&error_description=client_secret%3Dtop-secret"
        )

        XCTAssertTrue(result.body.contains("OAuth provider returned error invalid_request."))
        XCTAssertFalse(result.body.contains("client_secret"))
        XCTAssertFalse(result.body.contains("top-secret"))

        guard case OAuthCallbackServer.ServerError.oauthError(let code, let description) = result.error else {
            return XCTFail("Unexpected error: \(result.error)")
        }
        XCTAssertEqual(code, "invalid_request")
        XCTAssertEqual(description, "client_secret=top-secret")
        XCTAssertEqual(
            OAuthCallbackServer.ServerError.oauthError(
                code: code,
                description: description
            ).localizedDescription,
            "OAuth provider returned error invalid_request."
        )
    }

    func testProviderErrorDescriptionDoesNotEchoAuthorizationParameters() async throws {
        let result = try await callbackFailure(
            query: "error=invalid_request&error_description=state%3Dsecret-state%26code_challenge%3Dsecret-challenge"
        )

        XCTAssertTrue(result.body.contains("OAuth provider returned error invalid_request."))
        XCTAssertFalse(result.body.contains("secret-state"))
        XCTAssertFalse(result.body.contains("secret-challenge"))
        XCTAssertFalse(result.body.contains("code_challenge"))
        XCTAssertFalse(result.body.contains("state="))

        guard case OAuthCallbackServer.ServerError.oauthError(let code, let description) = result.error else {
            return XCTFail("Unexpected error: \(result.error)")
        }
        XCTAssertEqual(code, "invalid_request")
        XCTAssertEqual(description, "state=secret-state&code_challenge=secret-challenge")
        XCTAssertEqual(
            OAuthCallbackServer.ServerError.oauthError(
                code: code,
                description: description
            ).localizedDescription,
            "OAuth provider returned error invalid_request."
        )
    }
}

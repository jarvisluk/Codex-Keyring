import Foundation
import XCTest
@testable import CodexKeyringInfrastructure

final class OAuthCallbackServerTests: XCTestCase {
    func testCallbackBeforeWaiterStillReturnsCode() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )

        let response = try await request(
            await server.redirectURI,
            query: "code=auth-code&state=expected-state"
        )

        XCTAssertEqual(response.statusCode, 200)

        let result = try await server.waitForCode(timeout: .seconds(1))
        XCTAssertEqual(result.code, "auth-code")
        XCTAssertEqual(result.state, "expected-state")
    }

    func testDuplicateCallbackParameterIsRejectedWithoutCrashing() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(1))
        }

        let response = try await request(
            await server.redirectURI,
            query: "code=first&code=second&state=expected-state"
        )

        XCTAssertEqual(response.statusCode, 400)

        do {
            _ = try await waitTask.value
            XCTFail("Expected duplicate code parameter to fail the callback.")
        } catch OAuthCallbackServer.ServerError.duplicateParameter(let name) {
            XCTAssertEqual(name, "code")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProviderErrorDescriptionIsNotEchoedWhenItContainsTokenFields() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(1))
        }

        let result = try await requestData(
            await server.redirectURI,
            query: "error=access_denied&error_description=access_token%3Dsecret"
        )
        let body = String(data: result.data, encoding: .utf8) ?? ""

        XCTAssertEqual(result.response.statusCode, 400)
        XCTAssertTrue(body.contains("OAuth provider returned error access_denied."))
        XCTAssertFalse(body.contains("access_token"))
        XCTAssertFalse(body.contains("secret"))

        do {
            _ = try await waitTask.value
            XCTFail("Expected provider error to fail the callback.")
        } catch OAuthCallbackServer.ServerError.oauthError(let code, let description) {
            XCTAssertEqual(code, "access_denied")
            XCTAssertEqual(description, "access_token=secret")
            XCTAssertEqual(
                OAuthCallbackServer.ServerError.oauthError(
                    code: code,
                    description: description
                ).localizedDescription,
                "OAuth provider returned error access_denied."
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProviderErrorCodeIsSanitizedBeforeDisplay() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(1))
        }

        let result = try await requestData(
            await server.redirectURI,
            query: "error=access_token%3Dsecret"
        )
        let body = String(data: result.data, encoding: .utf8) ?? ""

        XCTAssertEqual(result.response.statusCode, 400)
        XCTAssertTrue(body.contains("OAuth provider returned an OAuth error."))
        XCTAssertFalse(body.contains("access_token"))
        XCTAssertFalse(body.contains("secret"))

        do {
            _ = try await waitTask.value
            XCTFail("Expected provider error to fail the callback.")
        } catch OAuthCallbackServer.ServerError.oauthError(let code, let description) {
            XCTAssertEqual(code, "access_token=secret")
            XCTAssertNil(description)
            XCTAssertEqual(
                OAuthCallbackServer.ServerError.oauthError(
                    code: code,
                    description: description
                ).localizedDescription,
                "OAuth provider returned an OAuth error."
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProviderErrorDescriptionDoesNotEchoOAuthClientSecrets() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(1))
        }

        let result = try await requestData(
            await server.redirectURI,
            query: "error=invalid_request&error_description=client_secret%3Dtop-secret"
        )
        let body = String(data: result.data, encoding: .utf8) ?? ""

        XCTAssertEqual(result.response.statusCode, 400)
        XCTAssertTrue(body.contains("OAuth provider returned error invalid_request."))
        XCTAssertFalse(body.contains("client_secret"))
        XCTAssertFalse(body.contains("top-secret"))

        do {
            _ = try await waitTask.value
            XCTFail("Expected provider error to fail the callback.")
        } catch OAuthCallbackServer.ServerError.oauthError(let code, let description) {
            XCTAssertEqual(code, "invalid_request")
            XCTAssertEqual(description, "client_secret=top-secret")
            XCTAssertEqual(
                OAuthCallbackServer.ServerError.oauthError(
                    code: code,
                    description: description
                ).localizedDescription,
                "OAuth provider returned error invalid_request."
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProviderErrorDescriptionDoesNotEchoAuthorizationParameters() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(1))
        }

        let result = try await requestData(
            await server.redirectURI,
            query: "error=invalid_request&error_description=state%3Dsecret-state%26code_challenge%3Dsecret-challenge"
        )
        let body = String(data: result.data, encoding: .utf8) ?? ""

        XCTAssertEqual(result.response.statusCode, 400)
        XCTAssertTrue(body.contains("OAuth provider returned error invalid_request."))
        XCTAssertFalse(body.contains("secret-state"))
        XCTAssertFalse(body.contains("secret-challenge"))
        XCTAssertFalse(body.contains("code_challenge"))
        XCTAssertFalse(body.contains("state="))

        do {
            _ = try await waitTask.value
            XCTFail("Expected provider error to fail the callback.")
        } catch OAuthCallbackServer.ServerError.oauthError(let code, let description) {
            XCTAssertEqual(code, "invalid_request")
            XCTAssertEqual(description, "state=secret-state&code_challenge=secret-challenge")
            XCTAssertEqual(
                OAuthCallbackServer.ServerError.oauthError(
                    code: code,
                    description: description
                ).localizedDescription,
                "OAuth provider returned error invalid_request."
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeoutClosesCallbackServer() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let redirectURI = await server.redirectURI

        do {
            _ = try await server.waitForCode(timeout: .milliseconds(10))
            XCTFail("Expected callback wait to time out.")
        } catch OAuthCallbackServer.ServerError.timedOut {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await request(redirectURI, query: "code=late-code&state=expected-state")
            XCTFail("Expected timed-out callback server to be closed.")
        } catch {
            XCTAssertTrue(
                (error as NSError).domain == NSURLErrorDomain,
                "Unexpected request error after timeout: \(error)"
            )
        }
    }

    func testCancellingWaitClosesCallbackServer() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let redirectURI = await server.redirectURI
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(30))
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        waitTask.cancel()

        do {
            _ = try await waitTask.value
            XCTFail("Expected cancelled callback wait to fail.")
        } catch OAuthCallbackServer.ServerError.cancelled {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await request(redirectURI, query: "code=late-code&state=expected-state")
            XCTFail("Expected cancelled callback server to be closed.")
        } catch {
            XCTAssertTrue(
                (error as NSError).domain == NSURLErrorDomain,
                "Unexpected request error after cancellation: \(error)"
            )
        }
    }

    private func request(_ redirectURI: String, query: String) async throws -> HTTPURLResponse {
        try await requestData(redirectURI, query: query).response
    }

    private func requestData(
        _ redirectURI: String,
        query: String
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let url = try XCTUnwrap(URL(string: "\(redirectURI)?\(query)"))
        let (data, response) = try await URLSession.shared.data(from: url)
        return (data, try XCTUnwrap(response as? HTTPURLResponse))
    }
}

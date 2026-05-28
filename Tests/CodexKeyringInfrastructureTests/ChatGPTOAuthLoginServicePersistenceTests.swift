import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTOAuthLoginServicePersistenceTests: ChatGPTOAuthLoginServiceTestCase {
    func testLoginWritesAuthFileAndCodexDirectoryPrivately() async throws {
        let fixture = try makeOAuthLoginServiceFixture()
        let idToken = try oauthTestJWT(payload: [
            "https://api.openai.com/auth": [
                "chatgpt_account_id": " account-123 "
            ]
        ])

        OAuthLoginURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.host, "auth.test")
            XCTAssertEqual(request.url?.path, "/oauth/token")
            let body = requestBodyString(from: request)
            XCTAssertTrue(body.contains("grant_type=authorization_code"))
            XCTAssertTrue(body.contains("code=callback-code"))
            return try .json([
                "id_token": idToken,
                "access_token": "access-token",
                "refresh_token": "refresh-token"
            ])
        }

        try await completeOAuthLogin(fixture.service)

        let object = try authObject(at: fixture.authFileURL)
        let tokens = try XCTUnwrap(object["tokens"] as? [String: Any])
        XCTAssertEqual(object["auth_mode"] as? String, "chatgpt")
        XCTAssertEqual(tokens["id_token"] as? String, idToken)
        XCTAssertEqual(tokens["access_token"] as? String, "access-token")
        XCTAssertEqual(tokens["refresh_token"] as? String, "refresh-token")
        XCTAssertEqual(tokens["account_id"] as? String, "account-123")
        XCTAssertEqual(try filePermissions(at: fixture.authFileURL), 0o600)
        XCTAssertEqual(try filePermissions(at: fixture.codexDirectory), 0o700)
    }

    func testLoginPersistsAuthOnConfiguredIOQueue() async throws {
        let fixture = try makeOAuthLoginServiceFixture()
        let idToken = try oauthTestJWT(payload: [
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "queued-account"
            ]
        ])
        let tokenRequested = expectation(description: "token endpoint requested")
        OAuthLoginURLProtocol.setHandler { _ in
            tokenRequested.fulfill()
            return try .json([
                "id_token": idToken,
                "access_token": "queued-access-token",
                "refresh_token": "queued-refresh-token"
            ])
        }

        let ioQueue = DispatchQueue(label: "tests.ChatGPTOAuthLoginService.suspended")
        let releaseQueue = blockSerialQueue(ioQueue, description: "oauth login io queue")
        var didReleaseQueue = false
        defer {
            if !didReleaseQueue {
                releaseQueue()
            }
        }
        let service = try makeOAuthLoginService(
            authFileURL: fixture.authFileURL,
            codexDirectory: fixture.codexDirectory,
            ioQueue: ioQueue
        )

        let loginTask = Task {
            try await completeOAuthLogin(service)
        }
        await fulfillment(of: [tokenRequested], timeout: 2)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.authFileURL.path))

        releaseQueue()
        didReleaseQueue = true
        try await loginTask.value
        let object = try authObject(at: fixture.authFileURL)
        let tokens = try XCTUnwrap(object["tokens"] as? [String: Any])
        XCTAssertEqual(tokens["account_id"] as? String, "queued-account")
        XCTAssertEqual(tokens["access_token"] as? String, "queued-access-token")
    }
}

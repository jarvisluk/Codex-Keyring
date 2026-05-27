import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTOAuthLoginServiceTests: XCTestCase {
    override func tearDown() {
        OAuthLoginURLProtocol.reset()
        super.tearDown()
    }

    func testOpenAIIssuerUsesAuthEndpoint() {
        XCTAssertEqual(
            ChatGPTOAuthLoginService.openAIIssuer.absoluteString,
            "https://auth.openai.com"
        )
    }

    func testLoginWritesAuthFileAndCodexDirectoryPrivately() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let authFileURL = codexDirectory.appendingPathComponent("auth.json")
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

        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: authFileURL,
            codexDirectory: codexDirectory,
            urlSession: OAuthLoginURLProtocol.session
        )

        try await service.loginWithChatGPT { authorizeURL in
            try await completeLoginCallback(for: authorizeURL)
        }

        let object = try authObject(at: authFileURL)
        let tokens = try XCTUnwrap(object["tokens"] as? [String: Any])
        XCTAssertEqual(object["auth_mode"] as? String, "chatgpt")
        XCTAssertEqual(tokens["id_token"] as? String, idToken)
        XCTAssertEqual(tokens["access_token"] as? String, "access-token")
        XCTAssertEqual(tokens["refresh_token"] as? String, "refresh-token")
        XCTAssertEqual(tokens["account_id"] as? String, "account-123")
        XCTAssertEqual(try filePermissions(at: authFileURL), 0o600)
        XCTAssertEqual(try filePermissions(at: codexDirectory), 0o700)
    }

    func testLoginPersistsAuthOnConfiguredIOQueue() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let authFileURL = codexDirectory.appendingPathComponent("auth.json")
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
        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: authFileURL,
            codexDirectory: codexDirectory,
            urlSession: OAuthLoginURLProtocol.session,
            ioQueue: ioQueue
        )

        let loginTask = Task {
            try await service.loginWithChatGPT { authorizeURL in
                try await completeLoginCallback(for: authorizeURL)
            }
        }
        await fulfillment(of: [tokenRequested], timeout: 2)

        XCTAssertFalse(FileManager.default.fileExists(atPath: authFileURL.path))

        releaseQueue()
        didReleaseQueue = true
        try await loginTask.value
        let object = try authObject(at: authFileURL)
        let tokens = try XCTUnwrap(object["tokens"] as? [String: Any])
        XCTAssertEqual(tokens["account_id"] as? String, "queued-account")
        XCTAssertEqual(tokens["access_token"] as? String, "queued-access-token")
    }

    func testLoginRejectsDirectoryAuthDestination() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let authFileURL = codexDirectory.appendingPathComponent("auth.json", isDirectory: true)
        try FileManager.default.createDirectory(at: authFileURL, withIntermediateDirectories: true)

        OAuthLoginURLProtocol.setHandler { _ in
            try .json([
                "id_token": try oauthTestJWT(payload: [:]),
                "access_token": "access-token",
                "refresh_token": "refresh-token"
            ])
        }

        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: authFileURL,
            codexDirectory: codexDirectory,
            urlSession: OAuthLoginURLProtocol.session
        )

        do {
            try await service.loginWithChatGPT { authorizeURL in
                try await completeLoginCallback(for: authorizeURL)
            }
            XCTFail("Expected login to reject a directory auth destination.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Auth destination is not a file"))
        }

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: authFileURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testTokenExchangeFailureSummarizesOAuthErrorWithoutEchoingTokenFields() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: tempDirectory.appendingPathComponent("codex/auth.json"),
            codexDirectory: tempDirectory.appendingPathComponent("codex", isDirectory: true),
            urlSession: OAuthLoginURLProtocol.session
        )

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
            try await service.loginWithChatGPT { authorizeURL in
                try await completeLoginCallback(for: authorizeURL)
            }
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
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: tempDirectory.appendingPathComponent("codex/auth.json"),
            codexDirectory: tempDirectory.appendingPathComponent("codex", isDirectory: true),
            urlSession: OAuthLoginURLProtocol.session
        )

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
            try await service.loginWithChatGPT { authorizeURL in
                try await completeLoginCallback(for: authorizeURL)
            }
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
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: tempDirectory.appendingPathComponent("codex/auth.json"),
            codexDirectory: tempDirectory.appendingPathComponent("codex", isDirectory: true),
            urlSession: OAuthLoginURLProtocol.session
        )

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
            try await service.loginWithChatGPT { authorizeURL in
                try await completeLoginCallback(for: authorizeURL)
            }
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

    func testTokenExchangeRejectsEmptyRequiredTokenFieldsBeforeWritingAuthFile() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let authFileURL = codexDirectory.appendingPathComponent("auth.json")
        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: authFileURL,
            codexDirectory: codexDirectory,
            urlSession: OAuthLoginURLProtocol.session
        )

        OAuthLoginURLProtocol.setHandler { _ in
            try .json([
                "id_token": "",
                "access_token": "access-token",
                "refresh_token": "refresh-token"
            ])
        }

        do {
            try await service.loginWithChatGPT { authorizeURL in
                try await completeLoginCallback(for: authorizeURL)
            }
            XCTFail("Expected empty token response fields to fail login.")
        } catch CodexKeyringError.codexLoginUnexpectedResponse(let reason) {
            XCTAssertEqual(reason, "Token response was missing required token fields.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: authFileURL.path))
    }

    func testBrowserOpenFailureDoesNotEchoAuthorizationURL() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let authFileURL = tempDirectory.appendingPathComponent("codex/auth.json")
        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("https://auth.test"),
            authFileURL: authFileURL,
            codexDirectory: tempDirectory.appendingPathComponent("codex", isDirectory: true),
            urlSession: OAuthLoginURLProtocol.session
        )

        do {
            try await service.loginWithChatGPT { authorizeURL in
                let leakedURLString = authorizeURL.absoluteString
                XCTAssertTrue(leakedURLString.contains("code_challenge="))
                XCTAssertTrue(leakedURLString.contains("state="))
                throw CodexKeyringError.codexLoginFailed(reason: "open failed: \(leakedURLString)")
            }
            XCTFail("Expected browser open failure.")
        } catch CodexKeyringError.codexLoginFailed(let reason) {
            XCTAssertEqual(reason, "Could not open browser for Codex login.")
            XCTAssertFalse(reason.contains("code_challenge"))
            XCTAssertFalse(reason.contains("state="))
            XCTAssertFalse(reason.contains("client_id"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: authFileURL.path))
        XCTAssertTrue(OAuthLoginURLProtocol.requests.isEmpty)
    }

    func testInvalidAuthorizationIssuerFailsWithoutOpeningBrowser() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let service = ChatGPTOAuthLoginService(
            issuer: try oauthTestURL("auth.test"),
            authFileURL: tempDirectory.appendingPathComponent("codex/auth.json"),
            codexDirectory: tempDirectory.appendingPathComponent("codex", isDirectory: true),
            urlSession: OAuthLoginURLProtocol.session
        )

        do {
            try await service.loginWithChatGPT { _ in
                XCTFail("Browser should not open when the authorization URL is invalid.")
            }
            XCTFail("Expected invalid issuer failure")
        } catch CodexKeyringError.codexLoginFailed(let reason) {
            XCTAssertEqual(reason, "Authorization issuer must include a scheme and host.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct OAuthLoginMockResponse {
    var statusCode: Int
    var headers: [String: String]
    var data: Data

    static func json(_ object: Any, statusCode: Int = 200) throws -> OAuthLoginMockResponse {
        OAuthLoginMockResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            data: try JSONSerialization.data(withJSONObject: object)
        )
    }
}

private final class OAuthLoginURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> OAuthLoginMockResponse)?
    nonisolated(unsafe) private static var capturedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.withLock { capturedRequests }
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAuthLoginURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func setHandler(_ handler: @escaping (URLRequest) throws -> OAuthLoginMockResponse) {
        lock.withLock {
            self.handler = handler
        }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            capturedRequests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let currentHandler = Self.lock.withLock {
                Self.capturedRequests.append(request)
                return Self.handler
            }
            guard let currentHandler else {
                throw URLError(.badServerResponse)
            }
            let response = try currentHandler(request)
            guard let url = request.url,
                  let http = HTTPURLResponse(
                      url: url,
                      statusCode: response.statusCode,
                      httpVersion: "HTTP/1.1",
                      headerFields: response.headers
                  )
            else {
                throw URLError(.badServerResponse)
            }
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func authObject(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func requestBodyString(from request: URLRequest) -> String {
    if let body = request.httpBody {
        return String(data: body, encoding: .utf8) ?? ""
    }
    guard let stream = request.httpBodyStream else { return "" }
    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }
    return String(data: data, encoding: .utf8) ?? ""
}

private func completeLoginCallback(for authorizeURL: URL, code: String = "callback-code") async throws {
    let components = try XCTUnwrap(URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false))
    let redirectURI = try XCTUnwrap(components.queryItems?.first { $0.name == "redirect_uri" }?.value)
    let state = try XCTUnwrap(components.queryItems?.first { $0.name == "state" }?.value)
    var callback = try XCTUnwrap(URLComponents(string: redirectURI))
    callback.queryItems = [
        URLQueryItem(name: "code", value: code),
        URLQueryItem(name: "state", value: state)
    ]
    _ = try await URLSession.shared.data(from: try XCTUnwrap(callback.url))
}

private func filePermissions(at url: URL) throws -> Int {
    let value = try XCTUnwrap(
        FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
    )
    return value.intValue & 0o777
}

private func oauthTestURL(
    _ string: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> URL {
    try XCTUnwrap(URL(string: string), file: file, line: line)
}

private func oauthTestJWT(payload: [String: Any]) throws -> String {
    let header = ["alg": "none", "typ": "JWT"]
    return [
        try oauthTestBase64URLJSON(header),
        try oauthTestBase64URLJSON(payload),
        "signature"
    ].joined(separator: ".")
}

private func oauthTestBase64URLJSON(_ object: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object)
    return data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

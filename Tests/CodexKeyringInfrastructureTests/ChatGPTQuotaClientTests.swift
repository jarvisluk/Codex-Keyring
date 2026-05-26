import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchesUsageWithHeadersAndParsesBuckets() async throws {
        let accessToken = makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus"
            ],
            "https://api.openai.com/profile": [
                "email": "token@example.com"
            ]
        ])
        let snapshotURL = try writeAuthJSON(accessToken: accessToken)
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/backend-api/wham/usage")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(accessToken)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "CodexKeyring")
            return try .json([
                "plan_type": "pro",
                "email": "person@example.com",
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 35,
                        "limit_window_seconds": 7 * 24 * 60 * 60,
                        "reset_at": 1_735_693_200
                    ],
                    "secondary_window": [
                        "used_percent": 10,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ],
                "credits": [
                    "has_credits": true,
                    "unlimited": false,
                    "balance": "12.5"
                ],
                "additional_rate_limits": [
                    [
                        "limit_name": "codex_other",
                        "metered_feature": "codex_other",
                        "rate_limit": [
                            "primary_window": [
                                "used_percent": 88,
                                "limit_window_seconds": 30 * 60,
                                "reset_at": 1_735_433_000
                            ]
                        ]
                    ]
                ]
            ])
        }

        let client = makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let snapshot = try XCTUnwrap(result.state.snapshot)
        let primary = try XCTUnwrap(snapshot.primaryBucket)
        let other = try XCTUnwrap(snapshot.buckets.first(where: { $0.limitID == "codex_other" }))

        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertEqual(snapshot.planType, "pro")
        XCTAssertEqual(snapshot.email, "person@example.com")
        XCTAssertEqual(primary.windows.map(\.windowDurationMinutes), [7 * 24 * 60, 5 * 60])
        XCTAssertEqual(primary.remainingPercent, 65)
        XCTAssertEqual(primary.credits?.balance, "12.5")
        XCTAssertEqual(primary.health, .ready)
        XCTAssertEqual(other.health, .low)
    }

    func testParsesCodexRateLimitsPayloadIntoFiveHourAndWeeklyWindows() async throws {
        let accessToken = makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeAuthJSON(accessToken: accessToken)
        MockURLProtocol.setHandler { _ in
            try .json([
                "rate_limits": [
                    "limit_id": "codex",
                    "limit_name": NSNull(),
                    "primary": [
                        "used_percent": 12,
                        "window_minutes": 5 * 60,
                        "resets_at": 1_778_325_473
                    ],
                    "secondary": [
                        "used_percent": 57,
                        "window_minutes": 7 * 24 * 60,
                        "resets_at": 1_778_589_620
                    ],
                    "credits": NSNull(),
                    "plan_type": "team",
                    "rate_limit_reached_type": NSNull()
                ]
            ])
        }

        let client = makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let primary = try XCTUnwrap(result.state.snapshot?.primaryBucket)

        XCTAssertEqual(primary.windows.map(\.windowDurationMinutes), [5 * 60, 7 * 24 * 60])
        XCTAssertEqual(primary.windows.map(\.remainingPercent), [88, 43])
        XCTAssertEqual(primary.planType, "team")
        XCTAssertFalse(primary.isUnlimited)
        XCTAssertEqual(primary.health, .ready)
    }

    func testBusinessRateLimitsWithoutWindowsParsesAsUnlimited() async throws {
        let accessToken = makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeAuthJSON(accessToken: accessToken)
        MockURLProtocol.setHandler { _ in
            try .json([
                "rate_limits": [
                    "limit_id": "codex",
                    "limit_name": NSNull(),
                    "primary": NSNull(),
                    "secondary": NSNull(),
                    "credits": [
                        "has_credits": false,
                        "unlimited": false,
                        "balance": NSNull()
                    ],
                    "plan_type": "business",
                    "rate_limit_reached_type": NSNull()
                ]
            ])
        }

        let client = makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let primary = try XCTUnwrap(result.state.snapshot?.primaryBucket)

        XCTAssertEqual(primary.planType, "business")
        XCTAssertTrue(primary.windows.isEmpty)
        XCTAssertTrue(primary.isUnlimited)
        XCTAssertEqual(primary.health, .ready)
    }

    func testExpiredAccessTokenRefreshesAndWritesSnapshotAndLiveAuth() async throws {
        let expiredAccess = makeJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let freshAccess = makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "pro"
            ]
        ])
        let snapshotURL = try writeAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let liveURL = snapshotURL.deletingLastPathComponent().appendingPathComponent("live-auth.json")
        try FileManager.default.copyItem(at: snapshotURL, to: liveURL)

        MockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/oauth/token":
                return try .json([
                    "access_token": freshAccess,
                    "refresh_token": "refresh-new"
                ])
            case "/backend-api/wham/usage":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(freshAccess)")
                return try .json([
                    "plan_type": "pro",
                    "rate_limit": [
                        "primary_window": [
                            "used_percent": 20,
                            "limit_window_seconds": 5 * 60 * 60,
                            "reset_at": 1_735_434_000
                        ]
                    ]
                ])
            default:
                XCTFail("unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return .status(404)
            }
        }

        let client = makeClient()
        let result = try await client.queryQuota(
            for: request(snapshotURL: snapshotURL, liveAuthFileURL: liveURL)
        )

        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token", "/backend-api/wham/usage"])
        XCTAssertEqual(result.updatedMetadata?.plan, "plus")
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 80)
        XCTAssertEqual(try tokenValue("access_token", in: snapshotURL), freshAccess)
        XCTAssertEqual(try tokenValue("refresh_token", in: snapshotURL), "refresh-new")
        XCTAssertEqual(try tokenValue("access_token", in: liveURL), freshAccess)
        XCTAssertEqual(try tokenValue("refresh_token", in: liveURL), "refresh-new")
    }

    func testRefreshTokenReusedLeavesSnapshotUnchanged() async throws {
        let expiredAccess = makeJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let originalData = try Data(contentsOf: snapshotURL)
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/oauth/token")
            return try .json(
                [
                    "error": [
                        "code": "refresh_token_reused"
                    ]
                ],
                statusCode: 401
            )
        }

        let client = makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected refresh token reuse to throw")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertTrue(reason.contains("already used"))
        }
        XCTAssertEqual(try Data(contentsOf: snapshotURL), originalData)
    }

    private func makeClient() -> ChatGPTQuotaClient {
        ChatGPTQuotaClient(
            baseURL: URL(string: "https://chatgpt.test/backend-api")!,
            issuer: URL(string: "https://auth.test")!,
            urlSession: MockURLProtocol.session
        )
    }

    private func request(
        snapshotURL: URL,
        liveAuthFileURL: URL? = nil
    ) -> AccountQuotaQueryRequest {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let account = CodexAccount(
            id: id,
            alias: "Test",
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            snapshotFileName: snapshotURL.lastPathComponent,
            fingerprint: "fingerprint",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
        return AccountQuotaQueryRequest(
            account: account,
            snapshotURL: snapshotURL,
            liveAuthFileURL: liveAuthFileURL
        )
    }
}

private struct MockResponse {
    var statusCode: Int
    var headers: [String: String]
    var data: Data

    static func json(_ object: Any, statusCode: Int = 200) throws -> MockResponse {
        MockResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            data: try JSONSerialization.data(withJSONObject: object)
        )
    }

    static func status(_ statusCode: Int) -> MockResponse {
        MockResponse(statusCode: statusCode, headers: [:], data: Data())
    }
}

private final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> MockResponse)?
    nonisolated(unsafe) private static var recordedRequests: [URLRequest] = []

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    static func setHandler(_ handler: @escaping (URLRequest) throws -> MockResponse) {
        lock.withLock {
            self.handler = handler
            recordedRequests = []
        }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            recordedRequests = []
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
            let currentHandler = Self.lock.withLock { Self.handler }
            guard let currentHandler else {
                throw URLError(.badServerResponse)
            }
            Self.lock.withLock { Self.recordedRequests.append(request) }
            let response = try currentHandler(request)
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func writeAuthJSON(
    accessToken: String,
    refreshToken: String = "refresh-token",
    idToken: String? = nil
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("auth.json")
    let idToken = idToken ?? makeJWT(payload: [
        "email": "person@example.com",
        "https://api.openai.com/auth": [
            "chatgpt_plan_type": "plus",
            "chatgpt_account_id": "account-123"
        ]
    ])
    let object: [String: Any] = [
        "auth_mode": "chatgpt",
        "tokens": [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "id_token": idToken,
            "account_id": "account-123"
        ]
    ]
    try JSONSerialization.data(withJSONObject: object).write(to: url)
    return url
}

private func tokenValue(_ key: String, in url: URL) throws -> String? {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let tokens = object?["tokens"] as? [String: Any]
    return tokens?[key] as? String
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

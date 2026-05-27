import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testDefaultBaseURLUsesChatGPTBackendAPIEndpoint() {
        XCTAssertEqual(
            ChatGPTQuotaClient.defaultBaseURL.absoluteString,
            "https://chatgpt.com/backend-api"
        )
    }

    func testFetchesUsageWithHeadersAndParsesBuckets() async throws {
        let accessToken = try makeJWT(payload: [
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

        let client = try makeClient()
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

    func testTokenMetadataTrimsJWTClaimsBeforeUsingThem() async throws {
        let accessToken = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": " account-from-token ",
                "chatgpt_plan_type": " team "
            ],
            "https://api.openai.com/profile": [
                "email": " token@example.com "
            ]
        ])
        let snapshotURL = try writeAuthJSON(accessToken: accessToken, accountID: nil)
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-from-token")
            return try .json([
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 5,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ]
            ])
        }

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))

        XCTAssertEqual(result.state.snapshot?.planType, "team")
        XCTAssertEqual(result.state.snapshot?.email, "token@example.com")
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 95)
    }

    func testUsageURLPreservesNestedBasePathWithTrailingSlash() async throws {
        let accessToken = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeAuthJSON(accessToken: accessToken)
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.test/backend-api/wham/usage")
            XCTAssertEqual(request.url?.path, "/backend-api/wham/usage")
            return try .json([
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 15,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ]
            ])
        }

        let client = try makeClient(baseURL: testURL("https://chatgpt.test/backend-api/"))
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))

        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.path }, ["/backend-api/wham/usage"])
        XCTAssertEqual(result.state.snapshot?.endpoint, "https://chatgpt.test/backend-api/wham/usage")
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 85)
    }

    func testQueryQuotaLoadsSnapshotOnConfiguredIOQueue() async throws {
        let oldAccessToken = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "old-account",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let queuedAccessToken = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "queued-account",
                "chatgpt_plan_type": "pro"
            ]
        ])
        let snapshotURL = try writeAuthJSON(accessToken: oldAccessToken)
        let ioQueue = DispatchQueue(label: "tests.ChatGPTQuotaClient.suspended")
        let releaseQueue = blockSerialQueue(ioQueue, description: "quota client io queue")
        var didReleaseQueue = false
        defer {
            if !didReleaseQueue {
                releaseQueue()
            }
        }
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(queuedAccessToken)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "queued-account")
            return try .json([
                "plan_type": "pro",
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 25,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ]
            ])
        }

        let client = try makeClient(ioQueue: ioQueue)
        let quotaRequest = request(snapshotURL: snapshotURL)
        let queryStarted = expectation(description: "quota query started")
        let quotaTask = Task {
            queryStarted.fulfill()
            return try await client.queryQuota(for: quotaRequest)
        }
        await fulfillment(of: [queryStarted], timeout: 1)

        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
        try overwriteAuthJSON(at: snapshotURL, accessToken: queuedAccessToken)

        releaseQueue()
        didReleaseQueue = true
        let result = try await quotaTask.value
        XCTAssertEqual(result.state.snapshot?.planType, "pro")
    }

    func testParsesCodexRateLimitsPayloadIntoFiveHourAndWeeklyWindows() async throws {
        let accessToken = try makeJWT(payload: [
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

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let primary = try XCTUnwrap(result.state.snapshot?.primaryBucket)

        XCTAssertEqual(primary.windows.map(\.windowDurationMinutes), [5 * 60, 7 * 24 * 60])
        XCTAssertEqual(primary.windows.map(\.remainingPercent), [88, 43])
        XCTAssertEqual(primary.planType, "team")
        XCTAssertFalse(primary.isUnlimited)
        XCTAssertEqual(primary.health, .ready)
    }

    func testBusinessRateLimitsWithoutWindowsParsesAsUnlimited() async throws {
        let accessToken = try makeJWT(payload: [
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

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let primary = try XCTUnwrap(result.state.snapshot?.primaryBucket)

        XCTAssertEqual(primary.planType, "business")
        XCTAssertTrue(primary.windows.isEmpty)
        XCTAssertTrue(primary.isUnlimited)
        XCTAssertEqual(primary.health, .ready)
    }

    func testRefreshOnlySnapshotRefreshesBeforeFetchingUsage() async throws {
        let snapshotURL = try writeRefreshOnlyAuthJSON(refreshToken: "refresh-only")
        let freshExpiry = Date().addingTimeInterval(3600).timeIntervalSince1970
        let freshAccess = try makeJWT(payload: [
            "exp": freshExpiry,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-refresh",
                "chatgpt_plan_type": "team"
            ],
            "https://api.openai.com/profile": [
                "email": "refresh@example.com"
            ]
        ])

        MockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/oauth/token":
                return try .json([
                    "access_token": freshAccess,
                    "refresh_token": "refresh-next"
                ])
            case "/backend-api/wham/usage":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(freshAccess)")
                XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-refresh")
                return try .json([
                    "plan_type": "team",
                    "email": "refresh@example.com",
                    "rate_limit": [
                        "primary_window": [
                            "used_percent": 40,
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

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))

        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token", "/backend-api/wham/usage"])
        XCTAssertEqual(result.updatedMetadata?.email, "refresh@example.com")
        XCTAssertEqual(result.updatedMetadata?.plan, "team")
        XCTAssertEqual(result.updatedMetadata?.accountIdentifier, "account-refresh")
        XCTAssertEqual(result.updatedMetadata?.tokenExpiresAt, Date(timeIntervalSince1970: freshExpiry))
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 60)
        XCTAssertEqual(try tokenValue("access_token", in: snapshotURL), freshAccess)
        XCTAssertEqual(try tokenValue("refresh_token", in: snapshotURL), "refresh-next")
        XCTAssertEqual(try tokenValue("account_id", in: snapshotURL), "account-refresh")
    }

    func testWhitespaceOnlySnapshotTokensRequireReloginBeforeNetworkRequest() async throws {
        let snapshotURL = try writeAuthJSON(accessToken: " \n\t ", refreshToken: "   ")
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected whitespace-only tokens to require relogin.")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertEqual(reason, "The saved auth snapshot has no access or refresh token.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testExpiredAccessTokenRefreshesAndWritesSnapshotAndLiveAuth() async throws {
        let expiredAccess = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let freshExpiry = Date().addingTimeInterval(3600).timeIntervalSince1970
        let freshAccess = try makeJWT(payload: [
            "exp": freshExpiry,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "pro"
            ]
        ])
        let snapshotURL = try writeAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let liveDirectory = snapshotURL.deletingLastPathComponent().appendingPathComponent("live", isDirectory: true)
        try FileManager.default.createDirectory(at: liveDirectory, withIntermediateDirectories: true)
        let liveURL = liveDirectory.appendingPathComponent("auth.json")
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

        let client = try makeClient()
        let result = try await client.queryQuota(
            for: request(snapshotURL: snapshotURL, liveAuthFileURL: liveURL)
        )

        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token", "/backend-api/wham/usage"])
        XCTAssertEqual(result.updatedMetadata?.plan, "pro")
        XCTAssertEqual(result.updatedMetadata?.tokenExpiresAt, Date(timeIntervalSince1970: freshExpiry))
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 80)
        XCTAssertEqual(try tokenValue("access_token", in: snapshotURL), freshAccess)
        XCTAssertEqual(try tokenValue("refresh_token", in: snapshotURL), "refresh-new")
        XCTAssertEqual(try tokenValue("access_token", in: liveURL), freshAccess)
        XCTAssertEqual(try tokenValue("refresh_token", in: liveURL), "refresh-new")
        XCTAssertEqual(try filePermissions(at: snapshotURL), 0o600)
        XCTAssertEqual(try filePermissions(at: liveURL), 0o600)
        XCTAssertEqual(try filePermissions(at: snapshotURL.deletingLastPathComponent()), 0o700)
        XCTAssertEqual(try filePermissions(at: liveDirectory), 0o700)
    }

    func testExpiredActiveTokenUpdatesLiveAuthBeforeSnapshotWriteFailure() async throws {
        let expiredAccess = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let freshAccess = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "pro"
            ]
        ])
        let snapshotURL = try writeAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let snapshotDirectory = snapshotURL.deletingLastPathComponent()
        let liveDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringLive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: liveDirectory, withIntermediateDirectories: true)
        let liveURL = liveDirectory.appendingPathComponent("auth.json")
        try FileManager.default.copyItem(at: snapshotURL, to: liveURL)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: snapshotDirectory.path)
            try? FileManager.default.removeItem(at: snapshotDirectory)
            try? FileManager.default.removeItem(at: liveDirectory)
        }

        MockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/oauth/token":
                try FileManager.default.removeItem(at: snapshotURL)
                try FileManager.default.removeItem(at: snapshotDirectory)
                FileManager.default.createFile(
                    atPath: snapshotDirectory.path,
                    contents: Data("not a directory".utf8)
                )
                return try .json([
                    "access_token": freshAccess,
                    "refresh_token": "refresh-new"
                ])
            default:
                XCTFail("unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return .status(404)
            }
        }

        let client = try makeClient()
        do {
            _ = try await client.queryQuota(
                for: request(snapshotURL: snapshotURL, liveAuthFileURL: liveURL)
            )
            XCTFail("Expected snapshot persistence to fail.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Could not write refreshed auth snapshot"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token"])
        XCTAssertEqual(try tokenValue("access_token", in: liveURL), freshAccess)
        XCTAssertEqual(try tokenValue("refresh_token", in: liveURL), "refresh-new")
    }

    func testEmptyRefreshAccessTokenFailsBeforeWritingSnapshot() async throws {
        let expiredAccess = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let originalData = try Data(contentsOf: snapshotURL)
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/oauth/token")
            return try .json([
                "access_token": "",
                "refresh_token": "refresh-new"
            ])
        }

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected empty refresh access token to fail.")
        } catch CodexKeyringError.quotaQueryFailed(let reason) {
            XCTAssertEqual(reason, "Token refresh returned no access token.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token"])
        XCTAssertEqual(try Data(contentsOf: snapshotURL), originalData)
    }

    func testRefreshTokenReusedLeavesSnapshotUnchanged() async throws {
        let expiredAccess = try makeJWT(payload: [
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

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected refresh token reuse to throw")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertTrue(reason.contains("already used"))
        }
        XCTAssertEqual(try Data(contentsOf: snapshotURL), originalData)
    }

    func testRefreshFailureSummarizesSafeOAuthDescription() async throws {
        let expiredAccess = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let originalData = try Data(contentsOf: snapshotURL)
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/oauth/token")
            return try .json(
                [
                    "error": "invalid_grant",
                    "error_description": "refresh token expired"
                ],
                statusCode: 401
            )
        }

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected refresh failure to require relogin.")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertTrue(reason.contains("OAuth token endpoint returned HTTP 401"))
            XCTAssertTrue(reason.contains("invalid_grant"))
            XCTAssertTrue(reason.contains("refresh token expired"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(try Data(contentsOf: snapshotURL), originalData)
    }

    func testRefreshFailureDoesNotEchoSensitiveOAuthDescription() async throws {
        let expiredAccess = try makeJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/oauth/token")
            return try .json(
                [
                    "error": "invalid_grant",
                    "error_description": "refresh_token=secret-refresh-token"
                ],
                statusCode: 401
            )
        }

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected refresh failure to require relogin.")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertTrue(reason.contains("OAuth token endpoint returned HTTP 401"))
            XCTAssertTrue(reason.contains("invalid_grant"))
            XCTAssertFalse(reason.contains("refresh_token"))
            XCTAssertFalse(reason.contains("secret-refresh-token"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMissingSnapshotThrowsDomainMissingErrorBeforeNetworkRequest() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
        let snapshotURL = directory.appendingPathComponent("auth.json")
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected missing snapshot to fail.")
        } catch CodexKeyringError.authFileMissing(let url) {
            XCTAssertEqual(url, snapshotURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testDirectorySnapshotThrowsDomainUnreadableErrorBeforeNetworkRequest() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshotURL = directory.appendingPathComponent("auth.json", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshotURL, withIntermediateDirectories: true)
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected directory snapshot to fail.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testMalformedSnapshotJSONThrowsDomainUnreadableErrorBeforeNetworkRequest() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshotURL = directory.appendingPathComponent("auth.json")
        try Data("{".utf8).write(to: snapshotURL)
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected malformed snapshot to fail.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    private func makeClient(
        baseURL: URL? = nil,
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.ChatGPTQuotaClient.\(UUID().uuidString)")
    ) throws -> ChatGPTQuotaClient {
        try ChatGPTQuotaClient(
            baseURL: baseURL ?? testURL("https://chatgpt.test/backend-api"),
            issuer: testURL("https://auth.test"),
            urlSession: MockURLProtocol.session,
            ioQueue: ioQueue
        )
    }

    private func request(
        snapshotURL: URL,
        liveAuthFileURL: URL? = nil
    ) -> AccountQuotaQueryRequest {
        let id = UUID(uuid: (
            0xAA, 0xAA, 0xAA, 0xAA,
            0xBB, 0xBB,
            0xCC, 0xCC,
            0xDD, 0xDD,
            0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE
        ))
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

private func writeAuthJSON(
    accessToken: String,
    refreshToken: String = "refresh-token",
    idToken: String? = nil,
    accountID: String? = "account-123"
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("auth.json")
    let idToken = try idToken ?? makeJWT(payload: [
        "email": "person@example.com",
        "https://api.openai.com/auth": [
            "chatgpt_plan_type": "plus",
            "chatgpt_account_id": "account-123"
        ]
    ])
    var tokens: [String: Any] = [
        "access_token": accessToken,
        "refresh_token": refreshToken,
        "id_token": idToken
    ]
    if let accountID {
        tokens["account_id"] = accountID
    }
    let object: [String: Any] = [
        "auth_mode": "chatgpt",
        "tokens": tokens
    ]
    try JSONSerialization.data(withJSONObject: object).write(to: url)
    return url
}

private func writeRefreshOnlyAuthJSON(refreshToken: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("auth.json")
    let object: [String: Any] = [
        "auth_mode": "chatgpt",
        "tokens": [
            "refresh_token": refreshToken
        ]
    ]
    try JSONSerialization.data(withJSONObject: object).write(to: url)
    return url
}

private func overwriteAuthJSON(
    at url: URL,
    accessToken: String,
    refreshToken: String = "refresh-token",
    idToken: String? = nil
) throws {
    let idToken = try idToken ?? makeJWT(payload: [
        "email": "person@example.com",
        "https://api.openai.com/auth": [
            "chatgpt_plan_type": "plus"
        ]
    ])
    let object: [String: Any] = [
        "auth_mode": "chatgpt",
        "tokens": [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "id_token": idToken
        ]
    ]
    try JSONSerialization.data(withJSONObject: object).write(to: url)
}

private func tokenValue(_ key: String, in url: URL) throws -> String? {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let tokens = object?["tokens"] as? [String: Any]
    return tokens?[key] as? String
}

private func filePermissions(at url: URL) throws -> Int {
    let value = try XCTUnwrap(
        FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
    )
    return value.intValue & 0o777
}

private func testURL(
    _ string: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> URL {
    try XCTUnwrap(URL(string: string), file: file, line: line)
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

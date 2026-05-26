import Foundation
import CodexKeyringDomain

public struct ChatGPTQuotaClient: AccountQuotaQuerying, @unchecked Sendable {
    public static let defaultBaseURL = URL(string: "https://chatgpt.com/backend-api")!

    private let baseURL: URL
    private let issuer: URL
    private let clientID: String
    private let urlSession: URLSession
    private let authReader: AuthFileReading

    public init(
        baseURL: URL = Self.defaultBaseURL,
        issuer: URL = ChatGPTOAuthLoginService.openAIIssuer,
        clientID: String = ChatGPTOAuthLoginService.clientID,
        urlSession: URLSession = .shared,
        authReader: AuthFileReading = AuthFileParser()
    ) {
        self.baseURL = baseURL
        self.issuer = issuer
        self.clientID = clientID
        self.urlSession = urlSession
        self.authReader = authReader
    }

    public func queryQuota(for request: AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult {
        var auth = try loadChatGPTAuth(from: request.snapshotURL)
        var updatedMetadata: AuthMetadata?

        if shouldRefreshAccessToken(auth.accessToken) {
            auth = try await refreshAndPersistAuth(auth, request: request)
            updatedMetadata = try await authReader.read(from: request.snapshotURL)
        }

        do {
            let payload = try await fetchUsage(accessToken: auth.accessToken, accountID: auth.accountID)
            let snapshot = try makeSnapshot(
                payload: payload,
                account: request.account,
                auth: auth
            )
            return AccountQuotaQueryResult(
                state: .available(snapshot),
                updatedMetadata: updatedMetadata
            )
        } catch QuotaClientError.unauthorized where auth.refreshToken?.isEmpty == false {
            auth = try await refreshAndPersistAuth(auth, request: request)
            updatedMetadata = try await authReader.read(from: request.snapshotURL)
            let payload = try await fetchUsage(accessToken: auth.accessToken, accountID: auth.accountID)
            let snapshot = try makeSnapshot(
                payload: payload,
                account: request.account,
                auth: auth
            )
            return AccountQuotaQueryResult(
                state: .available(snapshot),
                updatedMetadata: updatedMetadata
            )
        } catch QuotaClientError.unauthorized {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved access token was rejected and no refresh token is available.")
        }
    }

    // MARK: - Auth loading and refresh

    private func loadChatGPTAuth(from url: URL) throws -> StoredChatGPTAuth {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CodexKeyringError.authFileMissing(url)
        }
        let data = try Data(contentsOf: url)
        let object = try jsonObject(from: data)
        guard let tokens = object["tokens"] as? [String: Any] else {
            throw CodexKeyringError.unsupportedAuthShape
        }
        let authMode = object["auth_mode"] as? String ?? "chatgpt"
        guard authMode == "chatgpt" else {
            throw CodexKeyringError.quotaQueryFailed(reason: "Only ChatGPT OAuth accounts expose Codex quota.")
        }

        let accessToken = tokens["access_token"] as? String
        let refreshToken = tokens["refresh_token"] as? String
        guard accessToken?.isEmpty == false || refreshToken?.isEmpty == false else {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved auth snapshot has no access or refresh token.")
        }

        let tokenMetadata = TokenMetadata.from(accessToken: accessToken, idToken: tokens["id_token"] as? String)
        let accountID = nonEmpty(tokens["account_id"] as? String)
            ?? tokenMetadata.accountID

        return StoredChatGPTAuth(
            sourceObject: object,
            accessToken: accessToken ?? "",
            refreshToken: nonEmpty(refreshToken),
            idToken: nonEmpty(tokens["id_token"] as? String),
            accountID: accountID,
            planType: tokenMetadata.planType,
            email: tokenMetadata.email
        )
    }

    private func shouldRefreshAccessToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return true }
        guard let expiresAt = TokenMetadata.expiration(from: token) else { return false }
        return expiresAt <= Date().addingTimeInterval(60)
    }

    private func refreshAndPersistAuth(
        _ auth: StoredChatGPTAuth,
        request: AccountQuotaQueryRequest
    ) async throws -> StoredChatGPTAuth {
        guard let refreshToken = auth.refreshToken, !refreshToken.isEmpty else {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved access token expired and no refresh token is available.")
        }

        let refreshResponse = try await refreshTokens(refreshToken: refreshToken)
        var updated = auth
        updated.accessToken = refreshResponse.accessToken
        updated.refreshToken = refreshResponse.refreshToken ?? auth.refreshToken
        updated.idToken = refreshResponse.idToken ?? auth.idToken
        updated.accountID = updated.accountID
            ?? TokenMetadata.from(accessToken: refreshResponse.accessToken, idToken: refreshResponse.idToken).accountID

        try persist(updated, to: request.snapshotURL)
        if let liveAuthFileURL = request.liveAuthFileURL {
            try persist(updated, to: liveAuthFileURL)
        }
        return try loadChatGPTAuth(from: request.snapshotURL)
    }

    private func refreshTokens(refreshToken: String) async throws -> RefreshTokenResponse {
        let url = issuer.appendingPathComponent("oauth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CodexKeyringError.quotaQueryFailed(reason: "Token refresh returned a non-HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw CodexKeyringError.quotaRequiresRelogin(reason: refreshFailureReason(from: data))
            }
            throw CodexKeyringError.quotaQueryFailed(reason: "Token refresh returned HTTP \(http.statusCode).")
        }
        do {
            return try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
        } catch {
            throw CodexKeyringError.quotaQueryFailed(reason: "Token refresh returned unreadable JSON.")
        }
    }

    private func persist(_ auth: StoredChatGPTAuth, to url: URL) throws {
        var object = auth.sourceObject
        var tokens = object["tokens"] as? [String: Any] ?? [:]
        tokens["access_token"] = auth.accessToken
        if let refreshToken = auth.refreshToken {
            tokens["refresh_token"] = refreshToken
        }
        if let idToken = auth.idToken {
            tokens["id_token"] = idToken
        }
        if let accountID = auth.accountID {
            tokens["account_id"] = accountID
        }
        object["tokens"] = tokens
        object["auth_mode"] = "chatgpt"
        object["last_refresh"] = ChatGPTOAuthLoginService.iso8601String(from: Date())

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try data.write(to: temp, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temp.path)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw CodexKeyringError.fileSystemFailure(reason: "Could not write refreshed auth snapshot: \(error.localizedDescription)")
        }
    }

    // MARK: - Usage endpoint

    private func fetchUsage(accessToken: String, accountID: String?) async throws -> UsagePayload {
        guard !accessToken.isEmpty else {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved auth snapshot has no access token.")
        }
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexKeyring", forHTTPHeaderField: "User-Agent")
        if let accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CodexKeyringError.quotaQueryFailed(reason: "Quota endpoint returned a non-HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw QuotaClientError.unauthorized
            }
            throw CodexKeyringError.quotaQueryFailed(reason: "Quota endpoint returned HTTP \(http.statusCode).")
        }
        do {
            return try JSONDecoder().decode(UsagePayload.self, from: data)
        } catch {
            throw CodexKeyringError.quotaQueryFailed(reason: "Quota endpoint returned unreadable JSON.")
        }
    }

    private var usageURL: URL {
        URL(string: baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/wham/usage")!
    }

    private func makeSnapshot(
        payload: UsagePayload,
        account: CodexAccount,
        auth: StoredChatGPTAuth
    ) throws -> AccountQuotaSnapshot {
        let planType = nonEmpty(payload.planType)
            ?? nonEmpty(payload.rateLimit?.planType)
            ?? auth.planType
            ?? account.plan
        let email = nonEmpty(payload.email) ?? auth.email ?? account.email
        var buckets: [QuotaBucket] = []

        buckets.append(
            makeBucket(
                limitID: nonEmpty(payload.rateLimit?.limitID) ?? "codex",
                limitName: nonEmpty(payload.rateLimit?.limitName),
                planType: planType,
                rateLimit: payload.rateLimit,
                credits: payload.credits ?? payload.rateLimit?.credits,
                rateLimitReachedType: payload.rateLimitReachedType?.normalizedValue
                    ?? payload.rateLimit?.rateLimitReachedType?.normalizedValue
            )
        )

        for additional in payload.additionalRateLimits ?? [] {
            buckets.append(
                makeBucket(
                    limitID: nonEmpty(additional.meteredFeature),
                    limitName: nonEmpty(additional.limitName),
                    planType: planType,
                    rateLimit: additional.rateLimit,
                    credits: nil,
                    rateLimitReachedType: nil
                )
            )
        }

        buckets = buckets.filter {
            !$0.windows.isEmpty || $0.credits != nil || $0.rateLimitReachedType != nil || $0.isUnlimited
        }
        guard !buckets.isEmpty else {
            throw CodexKeyringError.quotaQueryFailed(reason: "No quota buckets were returned.")
        }

        return AccountQuotaSnapshot(
            accountID: account.id,
            planType: planType,
            email: email,
            fetchedAt: Date(),
            buckets: buckets,
            endpoint: usageURL.absoluteString
        )
    }

    private func makeBucket(
        limitID: String?,
        limitName: String?,
        planType: String?,
        rateLimit: RateLimitDetails?,
        credits: CreditsDTO?,
        rateLimitReachedType: String?
    ) -> QuotaBucket {
        let windows = [
            rateLimit?.primaryWindow,
            rateLimit?.secondaryWindow
        ].compactMap { $0?.asQuotaWindow }
        let quotaCredits = credits.map {
            QuotaCredits(balance: $0.balance, hasCredits: $0.hasCredits, unlimited: $0.unlimited)
        }
        return QuotaBucket(
            limitID: limitID,
            limitName: limitName,
            planType: planType,
            windows: windows,
            credits: quotaCredits,
            rateLimitReachedType: rateLimitReachedType
        )
    }

    // MARK: - Helpers

    private func jsonObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexKeyringError.authFileUnreadable
        }
        return object
    }

    private func refreshFailureReason(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "The refresh token was rejected."
        }
        if let error = object["error"] as? [String: Any],
           let code = error["code"] as? String
        {
            switch code {
            case "refresh_token_expired":
                return "The refresh token expired."
            case "refresh_token_reused":
                return "The refresh token was already used."
            case "refresh_token_invalidated":
                return "The refresh token was revoked."
            default:
                return "The refresh token was rejected."
            }
        }
        return "The refresh token was rejected."
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

private enum QuotaClientError: Error {
    case unauthorized
}

private struct StoredChatGPTAuth {
    var sourceObject: [String: Any]
    var accessToken: String
    var refreshToken: String?
    var idToken: String?
    var accountID: String?
    var planType: String?
    var email: String?
}

private struct RefreshTokenResponse: Decodable {
    let idToken: String?
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct UsagePayload: Decodable {
    let planType: String?
    let email: String?
    let rateLimit: RateLimitDetails?
    let credits: CreditsDTO?
    let rateLimitReachedType: ReachedTypeDTO?
    let additionalRateLimits: [AdditionalRateLimitDTO]?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case email
        case rateLimit = "rate_limit"
        case rateLimits = "rate_limits"
        case credits
        case rateLimitReachedType = "rate_limit_reached_type"
        case additionalRateLimits = "additional_rate_limits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        rateLimit = try container.decodeIfPresent(RateLimitDetails.self, forKey: .rateLimit)
            ?? container.decodeIfPresent(RateLimitDetails.self, forKey: .rateLimits)
        credits = try container.decodeIfPresent(CreditsDTO.self, forKey: .credits)
        rateLimitReachedType = try container.decodeIfPresent(ReachedTypeDTO.self, forKey: .rateLimitReachedType)
        additionalRateLimits = try container.decodeIfPresent([AdditionalRateLimitDTO].self, forKey: .additionalRateLimits)
    }
}

private struct AdditionalRateLimitDTO: Decodable {
    let limitName: String?
    let meteredFeature: String?
    let rateLimit: RateLimitDetails?

    enum CodingKeys: String, CodingKey {
        case limitName = "limit_name"
        case meteredFeature = "metered_feature"
        case rateLimit = "rate_limit"
    }
}

private struct RateLimitDetails: Decodable {
    let limitID: String?
    let limitName: String?
    let planType: String?
    let primaryWindow: RateLimitWindowDTO?
    let secondaryWindow: RateLimitWindowDTO?
    let credits: CreditsDTO?
    let rateLimitReachedType: ReachedTypeDTO?

    enum CodingKeys: String, CodingKey {
        case limitID = "limit_id"
        case limitName = "limit_name"
        case planType = "plan_type"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
        case primary
        case secondary
        case credits
        case rateLimitReachedType = "rate_limit_reached_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        limitID = try container.decodeIfPresent(String.self, forKey: .limitID)
        limitName = try container.decodeIfPresent(String.self, forKey: .limitName)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        primaryWindow = try container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .primaryWindow)
            ?? container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .primary)
        secondaryWindow = try container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .secondaryWindow)
            ?? container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .secondary)
        credits = try container.decodeIfPresent(CreditsDTO.self, forKey: .credits)
        rateLimitReachedType = try container.decodeIfPresent(ReachedTypeDTO.self, forKey: .rateLimitReachedType)
    }
}

private struct RateLimitWindowDTO: Decodable {
    let usedPercent: Double?
    let limitWindowSeconds: Int?
    let resetAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case windowMinutes = "window_minutes"
        case resetAt = "reset_at"
        case resetsAt = "resets_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decodeIfPresent(Double.self, forKey: .usedPercent)
        if let limitWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .limitWindowSeconds) {
            self.limitWindowSeconds = limitWindowSeconds
        } else if let windowMinutes = try container.decodeIfPresent(Int.self, forKey: .windowMinutes) {
            self.limitWindowSeconds = windowMinutes * 60
        } else {
            self.limitWindowSeconds = nil
        }
        resetAt = try container.decodeIfPresent(TimeInterval.self, forKey: .resetAt)
            ?? container.decodeIfPresent(TimeInterval.self, forKey: .resetsAt)
    }

    var asQuotaWindow: QuotaWindow? {
        guard let usedPercent else { return nil }
        let minutes = limitWindowSeconds.flatMap { seconds -> Int? in
            guard seconds > 0 else { return nil }
            return (seconds + 59) / 60
        }
        let resetDate = resetAt.map { Date(timeIntervalSince1970: $0) }
        return QuotaWindow(
            usedPercent: usedPercent,
            windowDurationMinutes: minutes,
            resetsAt: resetDate
        )
    }
}

private struct CreditsDTO: Decodable {
    let balance: String?
    let hasCredits: Bool
    let unlimited: Bool

    enum CodingKeys: String, CodingKey {
        case balance
        case hasCredits = "has_credits"
        case hasCreditsCamel = "hasCredits"
        case unlimited
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        balance = try container.decodeIfPresent(String.self, forKey: .balance)
        hasCredits = try container.decodeIfPresent(Bool.self, forKey: .hasCredits)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasCreditsCamel)
            ?? false
        unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited) ?? false
    }
}

private struct ReachedTypeDTO: Decodable {
    let normalizedValue: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case type
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           !singleValue.decodeNil(),
           let value = try? singleValue.decode(String.self) {
            normalizedValue = value
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        normalizedValue = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
    }
}

private struct TokenMetadata {
    let accountID: String?
    let planType: String?
    let email: String?

    static func from(accessToken: String?, idToken: String?) -> TokenMetadata {
        let accessPayload = accessToken.flatMap(decodeJWTPayload) ?? [:]
        let idPayload = idToken.flatMap(decodeJWTPayload) ?? [:]
        let authClaim = record(accessPayload["https://api.openai.com/auth"])
            ?? record(idPayload["https://api.openai.com/auth"])
        let profileClaim = record(accessPayload["https://api.openai.com/profile"])
            ?? record(idPayload["https://api.openai.com/profile"])

        return TokenMetadata(
            accountID: string(authClaim?["chatgpt_account_id"])
                ?? string(accessPayload["chatgpt_account_id"])
                ?? string(idPayload["chatgpt_account_id"]),
            planType: string(authClaim?["chatgpt_plan_type"]),
            email: string(profileClaim?["email"]) ?? string(accessPayload["email"]) ?? string(idPayload["email"])
        )
    }

    static func expiration(from token: String) -> Date? {
        guard let payload = decodeJWTPayload(token),
              let exp = payload["exp"] as? TimeInterval
        else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return object
    }

    private static func record(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func string(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}

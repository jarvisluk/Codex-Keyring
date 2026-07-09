import Foundation
import CodexKeyringDomain

extension ChatGPTQuotaHTTPClient {
    func fetchRateLimitResetCredits(
        accessToken: String,
        accountID: String?
    ) async throws -> RateLimitResetCreditsPayload {
        guard !accessToken.isEmpty else {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved auth snapshot has no access token.")
        }

        let request = makeRateLimitResetCreditsRequest(accessToken: accessToken, accountID: accountID)
        let (data, response) = try await urlSession.data(for: request)
        let http = try rateLimitResetCreditsHTTPResponse(from: response)

        try validateRateLimitResetCreditsStatus(http)
        return try decodeRateLimitResetCreditsPayload(data)
    }

    private func rateLimitResetCreditsHTTPResponse(from response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw CodexKeyringError.quotaQueryFailed(reason: "Rate limit reset credits endpoint returned a non-HTTP response.")
        }
        return http
    }

    private func validateRateLimitResetCreditsStatus(_ http: HTTPURLResponse) throws {
        guard !(200..<300).contains(http.statusCode) else { return }
        if http.statusCode == 401 {
            throw QuotaClientError.unauthorized
        }
        throw CodexKeyringError.quotaQueryFailed(reason: "Rate limit reset credits endpoint returned HTTP \(http.statusCode).")
    }

    private func decodeRateLimitResetCreditsPayload(_ data: Data) throws -> RateLimitResetCreditsPayload {
        do {
            return try JSONDecoder().decode(RateLimitResetCreditsPayload.self, from: data)
        } catch {
            throw CodexKeyringError.quotaQueryFailed(reason: "Rate limit reset credits endpoint returned unreadable JSON.")
        }
    }
}

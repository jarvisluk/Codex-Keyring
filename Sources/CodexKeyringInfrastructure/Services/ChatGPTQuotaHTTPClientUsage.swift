import Foundation
import CodexKeyringDomain

extension ChatGPTQuotaHTTPClient {
    func fetchUsage(accessToken: String, accountID: String?) async throws -> UsagePayload {
        guard !accessToken.isEmpty else {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved auth snapshot has no access token.")
        }

        let request = makeUsageRequest(accessToken: accessToken, accountID: accountID)
        let (data, response) = try await urlSession.data(for: request)
        let http = try usageHTTPResponse(from: response)

        try validateUsageStatus(http)
        return try decodeUsagePayload(data)
    }

    private func usageHTTPResponse(from response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw CodexKeyringError.quotaQueryFailed(reason: "Quota endpoint returned a non-HTTP response.")
        }
        return http
    }

    private func validateUsageStatus(_ http: HTTPURLResponse) throws {
        guard !(200..<300).contains(http.statusCode) else { return }
        if http.statusCode == 401 {
            throw QuotaClientError.unauthorized
        }
        throw CodexKeyringError.quotaQueryFailed(reason: "Quota endpoint returned HTTP \(http.statusCode).")
    }

    private func decodeUsagePayload(_ data: Data) throws -> UsagePayload {
        do {
            return try JSONDecoder().decode(UsagePayload.self, from: data)
        } catch {
            throw CodexKeyringError.quotaQueryFailed(reason: "Quota endpoint returned unreadable JSON.")
        }
    }
}

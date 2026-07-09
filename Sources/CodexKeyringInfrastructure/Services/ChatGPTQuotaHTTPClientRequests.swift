import Foundation

extension ChatGPTQuotaHTTPClient {
    func makeRefreshTokenRequest(refreshToken: String) throws -> URLRequest {
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
        return request
    }

    func makeUsageRequest(accessToken: String, accountID: String?) -> URLRequest {
        var request = URLRequest(url: usageURL)
        configureAuthenticatedGET(&request, accessToken: accessToken, accountID: accountID)
        return request
    }

    func makeRateLimitResetCreditsRequest(accessToken: String, accountID: String?) -> URLRequest {
        var request = URLRequest(url: rateLimitResetCreditsURL)
        configureAuthenticatedGET(&request, accessToken: accessToken, accountID: accountID)
        return request
    }

    private func configureAuthenticatedGET(
        _ request: inout URLRequest,
        accessToken: String,
        accountID: String?
    ) {
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexKeyring", forHTTPHeaderField: "User-Agent")
        if let accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
    }
}

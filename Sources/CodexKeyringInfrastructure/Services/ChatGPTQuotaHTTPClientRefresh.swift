import Foundation
import CodexKeyringDomain

extension ChatGPTQuotaHTTPClient {
    func refreshTokens(refreshToken: String) async throws -> RefreshTokenResponse {
        let request = try makeRefreshTokenRequest(refreshToken: refreshToken)
        let (data, response) = try await urlSession.data(for: request)
        let http = try tokenRefreshHTTPResponse(from: response)

        try validateTokenRefreshStatus(http, data: data)
        return try decodeRefreshTokenResponse(data)
    }

    private func tokenRefreshHTTPResponse(from response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw CodexKeyringError.quotaQueryFailed(reason: "Token refresh returned a non-HTTP response.")
        }
        return http
    }

    private func validateTokenRefreshStatus(_ http: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(http.statusCode) else { return }
        if http.statusCode == 401 {
            throw CodexKeyringError.quotaRequiresRelogin(
                reason: refreshFailureReason(statusCode: http.statusCode, data: data)
            )
        }
        throw CodexKeyringError.quotaQueryFailed(reason: "Token refresh returned HTTP \(http.statusCode).")
    }

    private func decodeRefreshTokenResponse(_ data: Data) throws -> RefreshTokenResponse {
        do {
            let decoded = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
            guard nonEmpty(decoded.accessToken) != nil else {
                throw CodexKeyringError.quotaQueryFailed(reason: "Token refresh returned no access token.")
            }
            return decoded
        } catch let error as CodexKeyringError {
            throw error
        } catch {
            throw CodexKeyringError.quotaQueryFailed(reason: "Token refresh returned unreadable JSON.")
        }
    }

    private func refreshFailureReason(statusCode: Int, data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return OAuthErrorSanitizer.tokenEndpointFailureReason(statusCode: statusCode, data: data)
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
                break
            }
        }
        return OAuthErrorSanitizer.tokenEndpointFailureReason(statusCode: statusCode, data: data)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}

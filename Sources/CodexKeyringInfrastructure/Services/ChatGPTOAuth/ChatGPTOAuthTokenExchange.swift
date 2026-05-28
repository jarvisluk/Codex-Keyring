import Foundation
import CodexKeyringDomain

struct ChatGPTOAuthTokenExchanger {
    let issuer: URL
    let clientID: String
    let urlSession: URLSession

    func exchangeCodeForTokens(
        code: String,
        redirectURI: String,
        pkce: PKCECodes
    ) async throws -> ExchangedTokens {
        let (data, response) = try await urlSession.data(
            for: makeTokenRequest(code: code, redirectURI: redirectURI, pkce: pkce)
        )
        guard let http = response as? HTTPURLResponse else {
            throw CodexKeyringError.codexLoginUnexpectedResponse(reason: "Non-HTTP response from token endpoint.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CodexKeyringError.codexLoginFailed(
                reason: OAuthErrorSanitizer.tokenEndpointFailureReason(
                    statusCode: http.statusCode,
                    data: data
                )
            )
        }

        do {
            let decoded = try JSONDecoder().decode(ChatGPTOAuthTokenResponse.self, from: data)
            return try decoded.validatedTokens()
        } catch let error as CodexKeyringError {
            throw error
        } catch {
            throw CodexKeyringError.codexLoginUnexpectedResponse(
                reason: "Could not decode token response: \(error.localizedDescription)"
            )
        }
    }
}

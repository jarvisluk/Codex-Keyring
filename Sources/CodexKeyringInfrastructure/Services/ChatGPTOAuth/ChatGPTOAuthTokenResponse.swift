import Foundation
import CodexKeyringDomain

struct ChatGPTOAuthTokenResponse: Decodable {
    let id_token: String
    let access_token: String
    let refresh_token: String

    func validatedTokens() throws -> ExchangedTokens {
        guard Self.nonEmpty(id_token) != nil,
              Self.nonEmpty(access_token) != nil,
              Self.nonEmpty(refresh_token) != nil else {
            throw CodexKeyringError.codexLoginUnexpectedResponse(
                reason: "Token response was missing required token fields."
            )
        }
        return ExchangedTokens(
            idToken: id_token,
            accessToken: access_token,
            refreshToken: refresh_token
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}

import Foundation
import CodexKeyringDomain

struct ChatGPTOAuthJSONPayload: Encodable {
    struct Tokens: Encodable {
        let id_token: String
        let access_token: String
        let refresh_token: String
        let account_id: String?
    }

    let auth_mode: String
    let OPENAI_API_KEY: String?
    let tokens: Tokens
    let last_refresh: String

    init(tokens: ExchangedTokens, date: Date = Date()) {
        let metadata = TokenMetadata.from(accessToken: nil, idToken: tokens.idToken)
        self.auth_mode = "chatgpt"
        self.OPENAI_API_KEY = nil
        self.tokens = Tokens(
            id_token: tokens.idToken,
            access_token: tokens.accessToken,
            refresh_token: tokens.refreshToken,
            account_id: metadata.accountID
        )
        self.last_refresh = ChatGPTOAuthLoginService.iso8601String(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case auth_mode
        case OPENAI_API_KEY
        case tokens
        case last_refresh
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(auth_mode, forKey: .auth_mode)
        try container.encode(OPENAI_API_KEY, forKey: .OPENAI_API_KEY)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(last_refresh, forKey: .last_refresh)
    }

    func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(self)
        } catch {
            throw CodexKeyringError.codexLoginFailed(
                reason: "Could not encode auth.json: \(error.localizedDescription)"
            )
        }
    }
}

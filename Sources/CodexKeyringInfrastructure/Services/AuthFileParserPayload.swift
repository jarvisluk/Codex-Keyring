import Foundation

struct AuthFileDTO: Decodable {
    let auth_mode: String?
    let tokens: TokensDTO?
    let OPENAI_API_KEY: String?
}

struct TokensDTO: Decodable {
    let account_id: String?
    let id_token: String?
    let access_token: String?
    let refresh_token: String?

    var hasRecognizedFields: Bool {
        AuthMetadataParsingString.normalizedNonEmpty(id_token) != nil
            || AuthMetadataParsingString.normalizedNonEmpty(access_token) != nil
            || AuthMetadataParsingString.normalizedNonEmpty(refresh_token) != nil
    }
}

enum AuthMetadataParsingString {
    static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    static func firstNonEmpty(_ values: String?...) -> String? {
        values.lazy.compactMap(normalizedNonEmpty).first
    }
}

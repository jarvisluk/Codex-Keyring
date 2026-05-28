import Foundation

struct AuthFileTokenClaims {
    let id: JWTClaims?
    let access: JWTClaims?

    init(tokens: TokensDTO?) {
        id = AuthMetadataParsingString.normalizedNonEmpty(tokens?.id_token)
            .flatMap(JWTPayloadDecoder.decode)
        access = AuthMetadataParsingString.normalizedNonEmpty(tokens?.access_token)
            .flatMap(JWTPayloadDecoder.decode)
    }

    var email: String? {
        AuthMetadataParsingString.firstNonEmpty(id?.email, access?.email)
    }

    var plan: String? {
        AuthMetadataParsingString.firstNonEmpty(
            access?.authClaim?.chatgpt_plan_type,
            id?.authClaim?.chatgpt_plan_type
        )
    }

    var tokenExpiresAt: Date? {
        guard let expiry = access?.exp ?? id?.exp else { return nil }
        return Date(timeIntervalSince1970: expiry)
    }
}

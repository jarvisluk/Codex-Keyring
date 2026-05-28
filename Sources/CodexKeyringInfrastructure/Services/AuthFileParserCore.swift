import Foundation
import CodexKeyringDomain

extension AuthFileParser {
    static func parseAuthFile(at url: URL, logger: AppLogger) throws -> AuthMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.notice("auth file missing at \(url.path)")
            throw CodexKeyringError.authFileMissing(url)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.error("failed to read auth file: \(String(describing: error))")
            throw CodexKeyringError.authFileUnreadable
        }

        let decoder = JSONDecoder()
        let dto: AuthFileDTO
        do {
            dto = try decoder.decode(AuthFileDTO.self, from: data)
        } catch {
            logger.error("failed to decode auth file: \(String(describing: error))")
            throw CodexKeyringError.authFileUnreadable
        }

        let hasAPIKey = AuthMetadataParsingString.normalizedNonEmpty(dto.OPENAI_API_KEY) != nil
        let tokens = dto.tokens
        guard hasAPIKey || tokens?.hasRecognizedFields == true else {
            throw CodexKeyringError.unsupportedAuthShape
        }

        let tokenClaims = AuthFileTokenClaims(tokens: tokens)
        let authMode = AuthMetadataParsingString.normalizedNonEmpty(dto.auth_mode)
            ?? (hasAPIKey ? "api-key" : "chatgpt")
        let fallbackAccountIdentifier = hasAPIKey
            ? AuthMetadata.apiKeyAccountIdentifier
            : AuthMetadata.unknownChatGPTAccountIdentifier
        let accountIdentifier = AuthMetadataParsingString.firstNonEmpty(
            tokens?.account_id,
            tokenClaims.access?.authClaim?.chatgpt_account_id,
            tokenClaims.id?.authClaim?.chatgpt_account_id
        ) ?? fallbackAccountIdentifier

        return AuthMetadata(
            email: tokenClaims.email ?? (hasAPIKey ? "API key account" : "Unknown account"),
            plan: tokenClaims.plan ?? (hasAPIKey ? "API key" : authMode),
            authMode: authMode,
            accountIdentifier: accountIdentifier,
            fingerprint: Self.fingerprint(for: data),
            tokenExpiresAt: tokenClaims.tokenExpiresAt
        )
    }
}

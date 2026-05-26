import CryptoKit
import Foundation
import os
import CodexKeyringDomain

public enum AuthMetadataError: LocalizedError, Equatable {
    case fileMissing
    case unreadableJSON
    case unsupportedAuthShape

    public var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "Codex auth.json was not found."
        case .unreadableJSON:
            return "The selected auth file is not readable JSON."
        case .unsupportedAuthShape:
            return "The file does not look like a Codex auth.json file."
        }
    }

    var asDomainError: CodexKeyringError {
        switch self {
        case .fileMissing:
            return .authFileMissing(URL(fileURLWithPath: "/"))
        case .unreadableJSON:
            return .authFileUnreadable
        case .unsupportedAuthShape:
            return .unsupportedAuthShape
        }
    }
}

/// Codable-backed parser for Codex `auth.json` files.
///
/// Conforms to ``AuthFileReading`` for protocol-driven injection while also
/// exposing a static convenience for code that still uses the legacy API.
public struct AuthFileParser: AuthFileReading {
    private let log = CodexKeyringLog.make(.authParser)

    public init() {}

    public func read(from url: URL) async throws -> AuthMetadata {
        try Self.parseAuthFile(at: url, logger: log)
    }

    public static func parseAuthFile(at url: URL) throws -> AuthMetadata {
        try parseAuthFile(at: url, logger: CodexKeyringLog.make(.authParser))
    }

    static func parseAuthFile(at url: URL, logger: Logger) throws -> AuthMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.notice("auth file missing at \(url.path, privacy: .public)")
            throw CodexKeyringError.authFileMissing(url)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let dto: AuthFileDTO
        do {
            dto = try decoder.decode(AuthFileDTO.self, from: data)
        } catch {
            logger.error("failed to decode auth file: \(String(describing: error), privacy: .public)")
            throw CodexKeyringError.authFileUnreadable
        }

        let hasAPIKey = (dto.OPENAI_API_KEY ?? "").isEmpty == false
        let tokens = dto.tokens
        guard hasAPIKey || tokens != nil else {
            throw CodexKeyringError.unsupportedAuthShape
        }

        let authMode = dto.auth_mode ?? (hasAPIKey ? "api-key" : "chatgpt")
        let accountIdentifier = tokens?.account_id ?? "api-key"
        var email = hasAPIKey ? "API key account" : "Unknown account"
        var plan = hasAPIKey ? "API key" : authMode
        var tokenExpiresAt: Date?

        if let claims = tokens?.id_token.flatMap(JWTPayloadDecoder.decode) {
            if let tokenEmail = claims.email, !tokenEmail.isEmpty {
                email = tokenEmail
            }
            if let expiry = claims.exp {
                tokenExpiresAt = Date(timeIntervalSince1970: expiry)
            }
            if let planType = claims.authClaim?.chatgpt_plan_type, !planType.isEmpty {
                plan = planType
            }
        }

        return AuthMetadata(
            email: email,
            plan: plan,
            authMode: authMode,
            accountIdentifier: accountIdentifier,
            fingerprint: Self.fingerprint(for: data),
            tokenExpiresAt: tokenExpiresAt
        )
    }

    static func fingerprint(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Legacy enum-style facade preserved so existing callers keep compiling
/// during the migration to use-case injection.
public enum AuthMetadataParser {
    public static func parseAuthFile(at url: URL) throws -> AuthMetadata {
        try AuthFileParser.parseAuthFile(at: url)
    }
}

private struct AuthFileDTO: Decodable {
    let auth_mode: String?
    let tokens: TokensDTO?
    let OPENAI_API_KEY: String?
}

private struct TokensDTO: Decodable {
    let account_id: String?
    let id_token: String?
}

private struct JWTClaims {
    let email: String?
    let exp: TimeInterval?
    let authClaim: AuthClaim?
}

private struct AuthClaim {
    let chatgpt_plan_type: String?
}

private enum JWTPayloadDecoder {
    static func decode(_ token: String) -> JWTClaims? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        let email = object["email"] as? String
        let exp = object["exp"] as? TimeInterval
        var authClaim: AuthClaim?
        if let claim = object["https://api.openai.com/auth"] as? [String: Any] {
            authClaim = AuthClaim(chatgpt_plan_type: claim["chatgpt_plan_type"] as? String)
        }
        return JWTClaims(email: email, exp: exp, authClaim: authClaim)
    }
}

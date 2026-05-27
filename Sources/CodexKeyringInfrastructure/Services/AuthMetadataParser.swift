import CryptoKit
import Foundation
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
public final class AuthFileParser: AuthFileReading, @unchecked Sendable {
    private let log = CodexKeyringLog.makeAppLogger(.authParser)
    private let ioQueue: DispatchQueue

    public init(
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.AuthFileParser")
    ) {
        self.ioQueue = ioQueue
    }

    public func read(from url: URL) async throws -> AuthMetadata {
        try await performIO {
            try Self.parseAuthFile(at: url, logger: self.log)
        }
    }

    public static func parseAuthFile(at url: URL) throws -> AuthMetadata {
        try parseAuthFile(at: url, logger: CodexKeyringLog.makeAppLogger(.authParser))
    }

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

        let hasAPIKey = normalizedNonEmpty(dto.OPENAI_API_KEY) != nil
        let tokens = dto.tokens
        guard hasAPIKey || tokens?.hasRecognizedFields == true else {
            throw CodexKeyringError.unsupportedAuthShape
        }

        let authMode = normalizedNonEmpty(dto.auth_mode) ?? (hasAPIKey ? "api-key" : "chatgpt")
        let idClaims = normalizedNonEmpty(tokens?.id_token).flatMap(JWTPayloadDecoder.decode)
        let accessClaims = normalizedNonEmpty(tokens?.access_token).flatMap(JWTPayloadDecoder.decode)
        let fallbackAccountIdentifier = hasAPIKey
            ? AuthMetadata.apiKeyAccountIdentifier
            : AuthMetadata.unknownChatGPTAccountIdentifier
        let accountIdentifier = normalizedNonEmpty(tokens?.account_id)
            ?? normalizedNonEmpty(accessClaims?.authClaim?.chatgpt_account_id)
            ?? normalizedNonEmpty(idClaims?.authClaim?.chatgpt_account_id)
            ?? fallbackAccountIdentifier
        var email = hasAPIKey ? "API key account" : "Unknown account"
        var plan = hasAPIKey ? "API key" : authMode
        var tokenExpiresAt: Date?

        if let tokenEmail = firstNonEmpty(idClaims?.email, accessClaims?.email) {
            email = tokenEmail
        }
        if let expiry = accessClaims?.exp ?? idClaims?.exp {
            tokenExpiresAt = Date(timeIntervalSince1970: expiry)
        }
        if let planType = firstNonEmpty(
            accessClaims?.authClaim?.chatgpt_plan_type,
            idClaims?.authClaim?.chatgpt_plan_type
        ) {
            plan = planType
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

    private func performIO<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values.lazy.compactMap(normalizedNonEmpty).first
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
    let access_token: String?
    let refresh_token: String?

    var hasRecognizedFields: Bool {
        normalizedNonEmpty(id_token) != nil
            || normalizedNonEmpty(access_token) != nil
            || normalizedNonEmpty(refresh_token) != nil
    }
}

private func normalizedNonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty
    else {
        return nil
    }
    return trimmed
}

private struct JWTClaims {
    let email: String?
    let exp: TimeInterval?
    let authClaim: AuthClaim?
}

private struct AuthClaim {
    let chatgpt_plan_type: String?
    let chatgpt_account_id: String?
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
        let profileClaim = object["https://api.openai.com/profile"] as? [String: Any]
        let email = object["email"] as? String ?? profileClaim?["email"] as? String
        let exp = object["exp"] as? TimeInterval
        var authClaim: AuthClaim?
        if let claim = object["https://api.openai.com/auth"] as? [String: Any] {
            authClaim = AuthClaim(
                chatgpt_plan_type: claim["chatgpt_plan_type"] as? String,
                chatgpt_account_id: claim["chatgpt_account_id"] as? String
            )
        }
        return JWTClaims(email: email, exp: exp, authClaim: authClaim)
    }
}

import CryptoKit
import Foundation

enum AuthMetadataError: LocalizedError {
    case fileMissing
    case unreadableJSON
    case unsupportedAuthShape

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "Codex auth.json was not found."
        case .unreadableJSON:
            return "The selected auth file is not readable JSON."
        case .unsupportedAuthShape:
            return "The file does not look like a Codex auth.json file."
        }
    }
}

enum AuthMetadataParser {
    static func parseAuthFile(at url: URL) throws -> AuthMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AuthMetadataError.fileMissing
        }

        let data = try Data(contentsOf: url)
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AuthMetadataError.unreadableJSON
        }

        let authMode = root["auth_mode"] as? String ?? inferAuthMode(from: root)
        let tokens = root["tokens"] as? [String: Any] ?? [:]
        let hasAPIKey = root["OPENAI_API_KEY"] is String
        guard !tokens.isEmpty || hasAPIKey else {
            throw AuthMetadataError.unsupportedAuthShape
        }

        let accountIdentifier = tokens["account_id"] as? String ?? "api-key"
        var email = hasAPIKey ? "API key account" : "Unknown account"
        var plan = hasAPIKey ? "API key" : authMode
        var tokenExpiresAt: Date?

        if let idToken = tokens["id_token"] as? String,
           let payload = decodeJWTPayload(idToken) {
            if let tokenEmail = payload["email"] as? String, !tokenEmail.isEmpty {
                email = tokenEmail
            }

            if let expiry = payload["exp"] as? TimeInterval {
                tokenExpiresAt = Date(timeIntervalSince1970: expiry)
            }

            if let auth = payload["https://api.openai.com/auth"] as? [String: Any],
               let planType = auth["chatgpt_plan_type"] as? String,
               !planType.isEmpty {
                plan = planType
            }
        }

        return AuthMetadata(
            email: email,
            plan: plan,
            authMode: authMode,
            accountIdentifier: accountIdentifier,
            fingerprint: fingerprint(for: data),
            tokenExpiresAt: tokenExpiresAt
        )
    }

    private static func inferAuthMode(from root: [String: Any]) -> String {
        if root["OPENAI_API_KEY"] is String {
            return "api-key"
        }
        return "chatgpt"
    }

    private static func fingerprint(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any]
        else {
            return nil
        }
        return dictionary
    }
}

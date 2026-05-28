import Foundation

struct TokenMetadata {
    let accountID: String?
    let planType: String?
    let email: String?

    static func from(accessToken: String?, idToken: String?) -> TokenMetadata {
        let accessPayload = accessToken.flatMap(decodeJWTPayload) ?? [:]
        let idPayload = idToken.flatMap(decodeJWTPayload) ?? [:]
        let authClaim = record(accessPayload["https://api.openai.com/auth"])
            ?? record(idPayload["https://api.openai.com/auth"])
        let profileClaim = record(accessPayload["https://api.openai.com/profile"])
            ?? record(idPayload["https://api.openai.com/profile"])

        return TokenMetadata(
            accountID: string(authClaim?["chatgpt_account_id"])
                ?? string(accessPayload["chatgpt_account_id"])
                ?? string(idPayload["chatgpt_account_id"]),
            planType: string(authClaim?["chatgpt_plan_type"]),
            email: string(profileClaim?["email"]) ?? string(accessPayload["email"]) ?? string(idPayload["email"])
        )
    }

    static func expiration(from token: String) -> Date? {
        guard let payload = decodeJWTPayload(token),
              let exp = payload["exp"] as? TimeInterval
        else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
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
        return object
    }

    private static func record(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func string(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

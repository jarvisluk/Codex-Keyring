import Foundation

struct JWTClaims {
    let email: String?
    let exp: TimeInterval?
    let authClaim: AuthClaim?
}

struct AuthClaim {
    let chatgpt_plan_type: String?
    let chatgpt_account_id: String?
}

enum JWTPayloadDecoder {
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

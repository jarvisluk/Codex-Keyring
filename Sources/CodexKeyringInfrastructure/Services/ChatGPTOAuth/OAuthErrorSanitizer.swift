import Foundation

enum OAuthErrorSanitizer {
    static func tokenEndpointFailureReason(statusCode: Int, data: Data) -> String {
        let prefix = "OAuth token endpoint returned HTTP \(statusCode)"
        guard let detail = safeTokenEndpointFailureDetail(from: data), !detail.isEmpty else {
            return "\(prefix)."
        }
        return "\(prefix): \(detail)"
    }

    static func providerErrorDescription(
        code: String,
        description: String?
    ) -> String {
        let errorLabel = providerErrorLabel(code)
        guard let detail = OAuthSafeErrorText.sanitize(description) else {
            return "OAuth provider returned \(errorLabel)."
        }
        return "OAuth provider returned \(errorLabel): \(detail)"
    }

    static func browserErrorMessage(code: String, description: String?) -> String {
        let errorLabel = providerErrorLabel(code)
        return OAuthSafeErrorText.sanitize(description) ?? "OAuth provider returned \(errorLabel)."
    }

    private static func safeTokenEndpointFailureDetail(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: data),
           let dictionary = object as? [String: Any] {
            let nestedError = dictionary["error"] as? [String: Any]
            let error = OAuthSafeErrorText.sanitize(dictionary["error"] as? String)
                ?? OAuthSafeErrorText.sanitize(nestedError?["code"] as? String)
                ?? OAuthSafeErrorText.sanitize(nestedError?["type"] as? String)
            let description = OAuthSafeErrorText.sanitize(dictionary["error_description"] as? String)
                ?? OAuthSafeErrorText.sanitize(dictionary["message"] as? String)
                ?? OAuthSafeErrorText.sanitize(nestedError?["error_description"] as? String)
                ?? OAuthSafeErrorText.sanitize(nestedError?["message"] as? String)
            let detail = [error, description]
                .compactMap { $0 }
                .joined(separator: " - ")
            return OAuthSafeErrorText.clipped(detail)
        }

        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return OAuthSafeErrorText.sanitize(text)
    }

    private static func providerErrorLabel(_ code: String) -> String {
        guard let safeCode = OAuthSafeErrorText.sanitize(code) else {
            return "an OAuth error"
        }
        return "error \(safeCode)"
    }
}

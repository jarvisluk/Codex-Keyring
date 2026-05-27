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
        guard let detail = safeFreeformString(description) else {
            return "OAuth provider returned \(errorLabel)."
        }
        return "OAuth provider returned \(errorLabel): \(detail)"
    }

    static func browserErrorMessage(code: String, description: String?) -> String {
        let errorLabel = providerErrorLabel(code)
        return safeFreeformString(description) ?? "OAuth provider returned \(errorLabel)."
    }

    private static func safeTokenEndpointFailureDetail(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: data),
           let dictionary = object as? [String: Any] {
            let nestedError = dictionary["error"] as? [String: Any]
            let error = safeFreeformString(dictionary["error"] as? String)
                ?? safeFreeformString(nestedError?["code"] as? String)
                ?? safeFreeformString(nestedError?["type"] as? String)
            let description = safeFreeformString(dictionary["error_description"] as? String)
                ?? safeFreeformString(dictionary["message"] as? String)
                ?? safeFreeformString(nestedError?["error_description"] as? String)
                ?? safeFreeformString(nestedError?["message"] as? String)
            let detail = [error, description]
                .compactMap { $0 }
                .joined(separator: " - ")
            return clipped(detail)
        }

        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return safeFreeformString(text)
    }

    private static func safeFreeformString(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        guard !containsSensitiveMarker(collapsed) else { return nil }
        return clipped(collapsed)
    }

    private static func providerErrorLabel(_ code: String) -> String {
        guard let safeCode = safeFreeformString(code) else {
            return "an OAuth error"
        }
        return "error \(safeCode)"
    }

    private static func containsSensitiveMarker(_ text: String) -> Bool {
        let markers = [
            "access_token",
            "refresh_token",
            "id_token",
            "OPENAI_API_KEY",
            "api_key",
            "authorization_code",
            "authorization:",
            "bearer ",
            "code=",
            "code_challenge",
            "client_secret",
            "code_verifier",
            "redirect_uri",
            "state=",
            "session_token",
            "sk-"
        ]
        return markers.contains { marker in
            text.localizedCaseInsensitiveContains(marker)
        }
    }

    private static func clipped(_ value: String, maxLength: Int = 240) -> String? {
        guard !value.isEmpty else { return nil }
        guard value.count > maxLength else { return value }
        return String(value.prefix(maxLength)) + "..."
    }
}

import Foundation

enum OAuthSafeErrorText {
    static func sanitize(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        guard !containsSensitiveMarker(collapsed) else { return nil }
        return clipped(collapsed)
    }

    static func clipped(_ value: String, maxLength: Int = 240) -> String? {
        guard !value.isEmpty else { return nil }
        guard value.count > maxLength else { return value }
        return String(value.prefix(maxLength)) + "..."
    }

    private static func containsSensitiveMarker(_ text: String) -> Bool {
        sensitiveMarkers.contains { marker in
            text.localizedCaseInsensitiveContains(marker)
        }
    }

    private static let sensitiveMarkers = [
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
}

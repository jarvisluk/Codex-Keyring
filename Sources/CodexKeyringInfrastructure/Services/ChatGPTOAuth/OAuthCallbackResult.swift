import Foundation

/// Result returned by the local OAuth callback server when the browser hits
/// `/auth/callback`.
struct OAuthCallbackResult: Sendable {
    let code: String
    let state: String
}

enum OAuthCallbackServerError: Error, LocalizedError {
    case bindFailed(String)
    case stateMismatch
    case oauthError(code: String, description: String?)
    case missingCode
    case duplicateParameter(String)
    case cancelled
    case timedOut

    var errorDescription: String? {
        switch self {
        case .bindFailed(let reason):
            return "Could not start local OAuth callback server: \(reason)"
        case .stateMismatch:
            return "The OAuth callback state did not match. The login was aborted to prevent CSRF."
        case .oauthError(let code, let description):
            return OAuthErrorSanitizer.providerErrorDescription(
                code: code,
                description: description
            )
        case .missingCode:
            return "OAuth callback did not include an authorization code."
        case .duplicateParameter(let name):
            return "OAuth callback included duplicate \(name) parameters."
        case .cancelled:
            return "The OAuth login was cancelled before it completed."
        case .timedOut:
            return "Timed out waiting for the OAuth callback from the browser."
        }
    }
}

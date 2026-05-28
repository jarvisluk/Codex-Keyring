import Foundation
import CodexKeyringDomain

extension ChatGPTOAuthLoginService {
    static let browserOpenFailureReason = "Could not open browser for Codex login."

    func buildAuthorizeURL(redirectURI: String, pkce: PKCECodes, state: String) throws -> URL {
        guard let scheme = issuer.scheme, !scheme.isEmpty,
              let host = issuer.host, !host.isEmpty else {
            throw CodexKeyringError.codexLoginFailed(reason: "Authorization issuer must include a scheme and host.")
        }

        let basePath = issuer.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = issuer.port
        components.path = basePath.isEmpty ? "/oauth/authorize" : "/\(basePath)/oauth/authorize"
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid profile email offline_access"),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "originator", value: "codex_keyring")
        ]
        guard let url = components.url else {
            throw CodexKeyringError.codexLoginFailed(reason: "Could not build authorization URL.")
        }
        return url
    }
}

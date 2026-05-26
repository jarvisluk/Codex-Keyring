import Foundation
import CodexKeyringDomain

/// Third-party OAuth 2.0 + PKCE login against `auth.openai.com`, modelled on
/// the upstream Codex CLI (`codex-rs/login/src/server.rs`).
///
/// We do **not** shell out to `codex app-server`; instead Codex Keyring
/// implements the full ChatGPT OAuth flow itself and writes the resulting
/// `auth.json` to `~/.codex/auth.json`, ready for the rest of the app to
/// snapshot/restore as needed.
public struct ChatGPTOAuthLoginService: CodexLoginServicing {
    public static let openAIIssuer = URL(string: "https://auth.openai.com")!
    /// OpenAI's public client identifier for the Codex CLI. Hard-coded just
    /// like the upstream Rust implementation.
    public static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    private let issuer: URL
    private let clientID: String
    private let authFileURL: URL
    private let codexDirectory: URL
    private let urlSession: URLSession
    private let log = CodexKeyringLog.makeAppLogger(.oauth)

    public init(
        issuer: URL = ChatGPTOAuthLoginService.openAIIssuer,
        clientID: String = ChatGPTOAuthLoginService.clientID,
        authFileURL: URL = AppPaths.codexAuthFile,
        codexDirectory: URL = AppPaths.codexDirectory,
        urlSession: URLSession = .shared
    ) {
        self.issuer = issuer
        self.clientID = clientID
        self.authFileURL = authFileURL
        self.codexDirectory = codexDirectory
        self.urlSession = urlSession
    }

    public func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        let pkce = PKCECodes.generate()
        let state = OAuthRandom.urlSafeToken(byteCount: 32)

        let server: OAuthCallbackServer
        do {
            server = try await OAuthCallbackServer.start(expectedState: state)
        } catch {
            log.error("failed to start callback server: \(error.localizedDescription)")
            throw CodexKeyringError.codexLoginFailed(reason: error.localizedDescription)
        }

        let redirectURI = await server.redirectURI
        let authorizeURL = buildAuthorizeURL(redirectURI: redirectURI, pkce: pkce, state: state)

        do {
            log.info("opening ChatGPT auth URL on port resolved from server")
            try await openAuthURL(authorizeURL)
        } catch {
            await server.shutdown()
            throw CodexKeyringError.codexLoginFailed(reason: "Could not open browser: \(error.localizedDescription)")
        }

        let callback: OAuthCallbackResult
        do {
            callback = try await server.waitForCode()
        } catch {
            await server.shutdown()
            log.error("callback wait failed: \(error.localizedDescription)")
            throw CodexKeyringError.codexLoginFailed(reason: error.localizedDescription)
        }
        await server.shutdown()

        let tokens: ExchangedTokens
        do {
            tokens = try await exchangeCodeForTokens(
                code: callback.code,
                redirectURI: redirectURI,
                pkce: pkce
            )
        } catch {
            log.error("token exchange failed: \(error.localizedDescription)")
            throw CodexKeyringError.codexLoginFailed(reason: "Token exchange failed: \(error.localizedDescription)")
        }

        do {
            try persistAuth(tokens: tokens)
        } catch let error as CodexKeyringError {
            throw error
        } catch {
            throw CodexKeyringError.codexLoginFailed(reason: "Could not write auth.json: \(error.localizedDescription)")
        }
    }

    private func buildAuthorizeURL(redirectURI: String, pkce: PKCECodes, state: String) -> URL {
        var components = URLComponents()
        components.scheme = issuer.scheme
        components.host = issuer.host
        components.port = issuer.port
        components.path = (issuer.path.isEmpty ? "" : issuer.path) + "/oauth/authorize"
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
            preconditionFailure("Could not build OpenAI authorize URL from \(components)")
        }
        return url
    }

    private func exchangeCodeForTokens(
        code: String,
        redirectURI: String,
        pkce: PKCECodes
    ) async throws -> ExchangedTokens {
        let tokenURL = issuer.appendingPathComponent("oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: pkce.codeVerifier)
        ]
        request.httpBody = Data(Self.formURLEncode(body).utf8)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CodexKeyringError.codexLoginUnexpectedResponse(reason: "Non-HTTP response from token endpoint.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw CodexKeyringError.codexLoginFailed(
                reason: "OAuth token endpoint returned HTTP \(http.statusCode): \(bodyText)"
            )
        }

        do {
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            return ExchangedTokens(
                idToken: decoded.id_token,
                accessToken: decoded.access_token,
                refreshToken: decoded.refresh_token
            )
        } catch {
            throw CodexKeyringError.codexLoginUnexpectedResponse(
                reason: "Could not decode token response: \(error.localizedDescription)"
            )
        }
    }

    private static func formURLEncode(_ items: [URLQueryItem]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?/")
        return items.map { item in
            let name = item.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? item.name
            let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(name)=\(value)"
        }.joined(separator: "&")
    }

    private func persistAuth(tokens: ExchangedTokens) throws {
        let accountID = JWTPayload.chatgptAccountID(from: tokens.idToken)

        let payload = AuthJSONPayload(
            auth_mode: "chatgpt",
            OPENAI_API_KEY: nil,
            tokens: AuthJSONPayload.Tokens(
                id_token: tokens.idToken,
                access_token: tokens.accessToken,
                refresh_token: tokens.refreshToken,
                account_id: accountID
            ),
            last_refresh: Self.iso8601String(from: Date())
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw CodexKeyringError.codexLoginFailed(reason: "Could not encode auth.json: \(error.localizedDescription)")
        }

        let manager = FileManager.default
        do {
            try manager.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not prepare \(codexDirectory.path): \(error.localizedDescription)")
        }

        let temp = codexDirectory.appendingPathComponent(".auth.json.codex-keyring-\(UUID().uuidString)")
        do {
            try data.write(to: temp, options: [.atomic])
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temp.path)
        } catch {
            try? manager.removeItem(at: temp)
            throw CodexKeyringError.fileSystemFailure(reason: "Could not stage auth.json: \(error.localizedDescription)")
        }

        do {
            if manager.fileExists(atPath: authFileURL.path) {
                _ = try manager.replaceItemAt(authFileURL, withItemAt: temp)
            } else {
                try manager.moveItem(at: temp, to: authFileURL)
            }
        } catch {
            try? manager.removeItem(at: temp)
            throw CodexKeyringError.fileSystemFailure(reason: "Could not install auth.json: \(error.localizedDescription)")
        }
    }
}

private struct ExchangedTokens: Sendable {
    let idToken: String
    let accessToken: String
    let refreshToken: String
}

private struct TokenResponse: Decodable {
    let id_token: String
    let access_token: String
    let refresh_token: String
}

private struct AuthJSONPayload: Encodable {
    struct Tokens: Encodable {
        let id_token: String
        let access_token: String
        let refresh_token: String
        let account_id: String?
    }

    let auth_mode: String
    let OPENAI_API_KEY: String?
    let tokens: Tokens
    let last_refresh: String

    enum CodingKeys: String, CodingKey {
        case auth_mode
        case OPENAI_API_KEY
        case tokens
        case last_refresh
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(auth_mode, forKey: .auth_mode)
        try container.encode(OPENAI_API_KEY, forKey: .OPENAI_API_KEY)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(last_refresh, forKey: .last_refresh)
    }
}

private enum JWTPayload {
    static func chatgptAccountID(from jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let accountID = object["chatgpt_account_id"] as? String, !accountID.isEmpty {
            return accountID
        }
        if let claim = object["https://api.openai.com/auth"] as? [String: Any],
           let accountID = claim["chatgpt_account_id"] as? String,
           !accountID.isEmpty {
            return accountID
        }
        return nil
    }
}

extension ChatGPTOAuthLoginService {
    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

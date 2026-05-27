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
    public static let openAIIssuer = BundledURL.https(host: "auth.openai.com")
    /// OpenAI's public client identifier for the Codex CLI. Hard-coded just
    /// like the upstream Rust implementation.
    public static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    private let issuer: URL
    private let clientID: String
    private let authFileURL: URL
    private let codexDirectory: URL
    private let urlSession: URLSession
    private let ioQueue: DispatchQueue
    private let log = CodexKeyringLog.makeAppLogger(.oauth)

    public init(
        issuer: URL = ChatGPTOAuthLoginService.openAIIssuer,
        clientID: String = ChatGPTOAuthLoginService.clientID,
        authFileURL: URL = AppPaths.codexAuthFile,
        codexDirectory: URL = AppPaths.codexDirectory,
        urlSession: URLSession = .shared,
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.ChatGPTOAuthLogin")
    ) {
        self.issuer = issuer
        self.clientID = clientID
        self.authFileURL = authFileURL
        self.codexDirectory = codexDirectory
        self.urlSession = urlSession
        self.ioQueue = ioQueue
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
        let authorizeURL: URL
        do {
            authorizeURL = try buildAuthorizeURL(redirectURI: redirectURI, pkce: pkce, state: state)
        } catch {
            await server.shutdown()
            log.error("failed to build authorization URL: \(error.localizedDescription)")
            throw error
        }

        do {
            log.info("opening ChatGPT auth URL on port resolved from server")
            try await openAuthURL(authorizeURL)
        } catch {
            await server.shutdown()
            log.error("failed to open browser for ChatGPT auth")
            throw CodexKeyringError.codexLoginFailed(reason: Self.browserOpenFailureReason)
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
        } catch let error as CodexKeyringError {
            log.error("token exchange failed: \(error.localizedDescription)")
            throw error
        } catch {
            log.error("token exchange failed: \(error.localizedDescription)")
            throw CodexKeyringError.codexLoginFailed(reason: "Token exchange failed: \(error.localizedDescription)")
        }

        do {
            try await persistAuth(tokens: tokens)
        } catch let error as CodexKeyringError {
            throw error
        } catch {
            throw CodexKeyringError.codexLoginFailed(reason: "Could not write auth.json: \(error.localizedDescription)")
        }
    }

    private func buildAuthorizeURL(redirectURI: String, pkce: PKCECodes, state: String) throws -> URL {
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
            throw CodexKeyringError.codexLoginFailed(
                reason: OAuthErrorSanitizer.tokenEndpointFailureReason(
                    statusCode: http.statusCode,
                    data: data
                )
            )
        }

        do {
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            guard Self.nonEmpty(decoded.id_token) != nil,
                  Self.nonEmpty(decoded.access_token) != nil,
                  Self.nonEmpty(decoded.refresh_token) != nil else {
                throw CodexKeyringError.codexLoginUnexpectedResponse(
                    reason: "Token response was missing required token fields."
                )
            }
            return ExchangedTokens(
                idToken: decoded.id_token,
                accessToken: decoded.access_token,
                refreshToken: decoded.refresh_token
            )
        } catch let error as CodexKeyringError {
            throw error
        } catch {
            throw CodexKeyringError.codexLoginUnexpectedResponse(
                reason: "Could not decode token response: \(error.localizedDescription)"
            )
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private static let browserOpenFailureReason = "Could not open browser for Codex login."

    private static func formURLEncode(_ items: [URLQueryItem]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?/")
        return items.map { item in
            let name = item.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? item.name
            let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(name)=\(value)"
        }.joined(separator: "&")
    }

    private func persistAuth(tokens: ExchangedTokens) async throws {
        try await performIO {
            try self.persistAuthOnCurrentQueue(tokens: tokens)
        }
    }

    private func persistAuthOnCurrentQueue(tokens: ExchangedTokens) throws {
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
        try ensureAuthDestinationIsFileIfPresent(fileManager: manager)

        do {
            try PrivateFilePermissions.createDirectory(at: codexDirectory, fileManager: manager)
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not prepare \(codexDirectory.path): \(error.localizedDescription)")
        }

        let temp = codexDirectory.appendingPathComponent(".auth.json.codex-keyring-\(UUID().uuidString)")
        do {
            try data.write(to: temp, options: [.atomic])
            try PrivateFilePermissions.setFile(at: temp, fileManager: manager)
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
            try PrivateFilePermissions.setFile(at: authFileURL, fileManager: manager)
        } catch {
            try? manager.removeItem(at: temp)
            throw CodexKeyringError.fileSystemFailure(reason: "Could not install auth.json: \(error.localizedDescription)")
        }
    }

    private func ensureAuthDestinationIsFileIfPresent(fileManager manager: FileManager) throws {
        var isDirectory = ObjCBool(false)
        guard manager.fileExists(atPath: authFileURL.path, isDirectory: &isDirectory) else {
            return
        }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Auth destination is not a file: \(authFileURL.path)"
            )
        }
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
        let parts = jwt.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
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
        if let accountID = nonEmpty(object["chatgpt_account_id"] as? String) {
            return accountID
        }
        if let claim = object["https://api.openai.com/auth"] as? [String: Any],
           let accountID = nonEmpty(claim["chatgpt_account_id"] as? String) {
            return accountID
        }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}

extension ChatGPTOAuthLoginService {
    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

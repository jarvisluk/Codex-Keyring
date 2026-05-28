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

    let issuer: URL
    let clientID: String
    let authFileURL: URL
    let codexDirectory: URL
    let urlSession: URLSession
    let ioQueue: DispatchQueue
    let log = CodexKeyringLog.makeAppLogger(.oauth)

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
}

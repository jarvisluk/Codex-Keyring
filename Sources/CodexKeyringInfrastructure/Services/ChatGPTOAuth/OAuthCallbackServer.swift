import Darwin
import Foundation
import CodexKeyringDomain

/// A minimal localhost HTTP server that handles the OpenAI OAuth redirect.
///
/// Implemented on top of plain BSD sockets because `Network.framework`'s
/// `NWListener` started failing with `POSIXError(EINVAL)` on macOS 26 for
/// loopback listeners in unsigned/sandbox-less app bundles. The behaviour
/// otherwise mirrors `codex-rs/login/src/server.rs`: it serves
/// `GET /auth/callback?code=...&state=...`, validates the `state`, and then
/// renders a small success or error page in the browser.
actor OAuthCallbackServer {
    /// OpenAI's Hydra installation white-lists `localhost:1455` as the default
    /// redirect URI for the public Codex client, falling back to 1457.
    static let defaultPort: UInt16 = 1455
    static let fallbackPort: UInt16 = 1457

    typealias ServerError = OAuthCallbackServerError

    let expectedState: String
    let listener: OAuthListenerState
    let port: UInt16
    let acceptQueue = DispatchQueue(label: "com.junrong.CodexKeyring.oauth.accept", qos: .userInitiated)
    let connectionQueue = DispatchQueue(
        label: "com.junrong.CodexKeyring.oauth.conn",
        qos: .userInitiated,
        attributes: .concurrent
    )
    let log = CodexKeyringLog.makeAppLogger(.oauth)

    var continuation: CheckedContinuation<OAuthCallbackResult, Error>?
    var didFinish = false
    var finishedResult: Result<OAuthCallbackResult, Error>?

    init(expectedState: String, listener: OAuthListenerState, port: UInt16) {
        self.expectedState = expectedState
        self.listener = listener
        self.port = port
    }

    var redirectURI: String {
        "http://localhost:\(port)/auth/callback"
    }
}

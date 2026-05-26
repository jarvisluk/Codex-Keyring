import Darwin
import Foundation
import CodexKeyringDomain

/// Result returned by the local OAuth callback server when the browser hits
/// `/auth/callback`.
struct OAuthCallbackResult: Sendable {
    let code: String
    let state: String
}

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

    enum ServerError: Error, LocalizedError {
        case bindFailed(String)
        case stateMismatch
        case oauthError(code: String, description: String?)
        case missingCode
        case cancelled
        case timedOut

        var errorDescription: String? {
            switch self {
            case .bindFailed(let reason):
                return "Could not start local OAuth callback server: \(reason)"
            case .stateMismatch:
                return "The OAuth callback state did not match. The login was aborted to prevent CSRF."
            case .oauthError(let code, let description):
                if let description, !description.isEmpty {
                    return "OAuth provider returned error \(code): \(description)"
                }
                return "OAuth provider returned error \(code)."
            case .missingCode:
                return "OAuth callback did not include an authorization code."
            case .cancelled:
                return "The OAuth login was cancelled before it completed."
            case .timedOut:
                return "Timed out waiting for the OAuth callback from the browser."
            }
        }
    }

    private let expectedState: String
    private let listenerFD: Int32
    private let port: UInt16
    private let acceptQueue = DispatchQueue(label: "com.junrong.CodexKeyring.oauth.accept", qos: .userInitiated)
    private let connectionQueue = DispatchQueue(
        label: "com.junrong.CodexKeyring.oauth.conn",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let log = CodexKeyringLog.makeAppLogger(.oauth)

    private var continuation: CheckedContinuation<OAuthCallbackResult, Error>?
    private var didFinish = false
    private var acceptingStopped = false

    private init(expectedState: String, listenerFD: Int32, port: UInt16) {
        self.expectedState = expectedState
        self.listenerFD = listenerFD
        self.port = port
    }

    var redirectURI: String {
        "http://localhost:\(port)/auth/callback"
    }

    /// Binds to `defaultPort` first, falling back to `fallbackPort` and then to
    /// an arbitrary ephemeral port. The chosen port is exposed via `port`.
    static func start(expectedState: String) async throws -> OAuthCallbackServer {
        let candidates: [UInt16] = [defaultPort, fallbackPort, 0]
        var lastError: String = "no port available"
        for candidate in candidates {
            do {
                let (fd, port) = try bind(port: candidate)
                let server = OAuthCallbackServer(
                    expectedState: expectedState,
                    listenerFD: fd,
                    port: port
                )
                await server.startAccepting()
                return server
            } catch let ServerError.bindFailed(reason) {
                lastError = reason
                continue
            } catch {
                lastError = error.localizedDescription
                continue
            }
        }
        throw ServerError.bindFailed(lastError)
    }

    private static func bind(port requestedPort: UInt16) throws -> (Int32, UInt16) {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw ServerError.bindFailed("socket() failed: \(posixDescription(errno))")
        }

        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = requestedPort.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bindResult != 0 {
            let reason = posixDescription(errno)
            close(fd)
            throw ServerError.bindFailed("bind(127.0.0.1:\(requestedPort)) failed: \(reason)")
        }

        if listen(fd, 16) != 0 {
            let reason = posixDescription(errno)
            close(fd)
            throw ServerError.bindFailed("listen() failed: \(reason)")
        }

        var actual = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actual) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getsockname(fd, sa, &len)
            }
        }
        let port = UInt16(bigEndian: actual.sin_port)
        return (fd, port == 0 ? requestedPort : port)
    }

    /// Awaits the next valid `/auth/callback` request, with a timeout (defaults
    /// to 120 seconds to match the upstream Codex behaviour).
    func waitForCode(timeout: Duration = .seconds(120)) async throws -> OAuthCallbackResult {
        try await withThrowingTaskGroup(of: OAuthCallbackResult.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OAuthCallbackResult, Error>) in
                    Task { await self.installContinuation(continuation) }
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ServerError.timedOut
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw ServerError.cancelled
            }
            return first
        }
    }

    private func installContinuation(_ continuation: CheckedContinuation<OAuthCallbackResult, Error>) {
        if didFinish {
            continuation.resume(throwing: ServerError.cancelled)
            return
        }
        self.continuation = continuation
    }

    func shutdown() {
        finish(with: .failure(ServerError.cancelled))
    }

    private func finish(with result: Result<OAuthCallbackResult, Error>) {
        guard !didFinish else { return }
        didFinish = true
        acceptingStopped = true
        let pending = continuation
        continuation = nil

        if listenerFD >= 0 {
            Darwin.shutdown(listenerFD, SHUT_RDWR)
            close(listenerFD)
        }

        switch result {
        case .success(let value):
            pending?.resume(returning: value)
        case .failure(let error):
            pending?.resume(throwing: error)
        }
    }

    private func startAccepting() {
        let fd = listenerFD
        acceptQueue.async { [weak self] in
            self?.acceptLoop(fd: fd)
        }
    }

    private nonisolated func acceptLoop(fd: Int32) {
        while true {
            var clientAddr = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr -> Int32 in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.accept(fd, sa, &len)
                }
            }
            if clientFD < 0 {
                let captured = errno
                if captured == EINTR { continue }
                // Listener was closed (EBADF) or interrupted; exit the loop.
                return
            }
            _ = fcntl(clientFD, F_SETFD, FD_CLOEXEC)
            connectionQueue.async { [weak self] in
                guard let self else {
                    close(clientFD)
                    return
                }
                self.handleConnection(clientFD: clientFD)
            }
        }
    }

    private nonisolated func handleConnection(clientFD: Int32) {
        var tv = timeval(tv_sec: 10, tv_usec: 0)
        _ = setsockopt(clientFD, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(clientFD, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var buffer = Data()
        let chunkSize = 4096
        var scratch = [UInt8](repeating: 0, count: chunkSize)
        while buffer.count < 32 * 1024 {
            let bytesRead = scratch.withUnsafeMutableBytes { ptr in
                Darwin.read(clientFD, ptr.baseAddress, chunkSize)
            }
            if bytesRead <= 0 { break }
            buffer.append(scratch, count: bytesRead)
            if buffer.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) != nil {
                break
            }
        }

        let headerData: Data
        if let headerEnd = buffer.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) {
            headerData = buffer.subdata(in: 0..<headerEnd.lowerBound)
        } else {
            headerData = buffer
        }

        let requestLine = Self.firstLine(of: headerData)
        let components = requestLine.split(separator: " ")
        guard components.count >= 2, components[0] == "GET" else {
            Self.writeResponse(clientFD: clientFD, status: 405, reason: "Method Not Allowed", body: "Method Not Allowed")
            close(clientFD)
            return
        }
        let target = String(components[1])
        guard let url = URL(string: "http://localhost\(target)") else {
            Self.writeResponse(clientFD: clientFD, status: 400, reason: "Bad Request", body: "Bad Request")
            close(clientFD)
            return
        }
        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch path {
        case "/auth/callback":
            // Ownership of the fd transfers to the actor-bound `handleCallback`,
            // which writes the response and then closes the socket itself.
            Task { await self.handleCallback(queryItems: queryItems, clientFD: clientFD) }
        case "/":
            Self.writeResponse(clientFD: clientFD, status: 200, reason: "OK", body: "Codex Keyring OAuth callback server is running.")
            close(clientFD)
        default:
            Self.writeResponse(clientFD: clientFD, status: 404, reason: "Not Found", body: "Not Found")
            close(clientFD)
        }
    }

    private static func firstLine(of data: Data) -> String {
        if let crlf = data.range(of: Data([0x0D, 0x0A])) {
            return String(data: data.subdata(in: 0..<crlf.lowerBound), encoding: .utf8) ?? ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func handleCallback(queryItems: [URLQueryItem], clientFD: Int32) {
        let params = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })

        if let errorCode = params["error"], !errorCode.isEmpty {
            let description = params["error_description"]
            Self.renderErrorPage(clientFD: clientFD, message: description ?? errorCode)
            close(clientFD)
            log.error("oauth callback returned error: \(errorCode)")
            finish(with: .failure(ServerError.oauthError(code: errorCode, description: description)))
            return
        }

        let stateValue = params["state"] ?? ""
        guard stateValue == expectedState else {
            Self.renderErrorPage(clientFD: clientFD, message: "State mismatch.")
            close(clientFD)
            log.error("oauth callback state mismatch")
            finish(with: .failure(ServerError.stateMismatch))
            return
        }

        guard let code = params["code"], !code.isEmpty else {
            Self.renderErrorPage(clientFD: clientFD, message: "Missing authorization code.")
            close(clientFD)
            log.error("oauth callback missing code")
            finish(with: .failure(ServerError.missingCode))
            return
        }

        Self.renderSuccessPage(clientFD: clientFD)
        close(clientFD)
        log.info("oauth callback succeeded")
        finish(with: .success(OAuthCallbackResult(code: code, state: stateValue)))
    }

    private static func renderSuccessPage(clientFD: Int32) {
        let body = """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>Sign-in complete</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #0b0b0c; color: #f5f5f7; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { max-width: 420px; padding: 32px; background: #1c1c1f; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.4); text-align: center; }
        h1 { font-size: 22px; margin: 0 0 12px; }
        p { color: #c7c7cc; line-height: 1.5; margin: 0; }
        </style></head>
        <body><div class="card"><h1>Signed in to ChatGPT</h1><p>You can close this window and return to Codex Keyring.</p></div></body></html>
        """
        writeResponse(clientFD: clientFD, status: 200, reason: "OK", body: body, contentType: "text/html; charset=utf-8")
    }

    private static func renderErrorPage(clientFD: Int32, message: String) {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let body = """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>Sign-in failed</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #1a0b0b; color: #f5f5f7; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { max-width: 480px; padding: 32px; background: #2a1010; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.4); text-align: center; }
        h1 { font-size: 22px; margin: 0 0 12px; color: #ff6b6b; }
        p { color: #f4d6d6; line-height: 1.5; margin: 0; word-break: break-word; }
        </style></head>
        <body><div class="card"><h1>Sign-in failed</h1><p>\(escaped)</p></div></body></html>
        """
        writeResponse(clientFD: clientFD, status: 400, reason: "Bad Request", body: body, contentType: "text/html; charset=utf-8")
    }

    private static func writeResponse(
        clientFD: Int32,
        status: Int,
        reason: String,
        body: String,
        contentType: String = "text/plain; charset=utf-8"
    ) {
        let bodyData = Data(body.utf8)
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(bodyData.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(bodyData)
        _ = response.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            var sent = 0
            while sent < ptr.count {
                let written = Darwin.write(clientFD, base.advanced(by: sent), ptr.count - sent)
                if written <= 0 { return sent }
                sent += written
            }
            return sent
        }
    }
}

private func posixDescription(_ code: Int32) -> String {
    String(cString: strerror(code))
}

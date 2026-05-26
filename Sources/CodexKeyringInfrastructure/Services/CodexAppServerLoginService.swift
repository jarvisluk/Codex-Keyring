import Foundation
import CodexKeyringDomain

public struct CodexAppServerLoginService: Sendable {
    public init() {}

    public func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try await CodexAppServerLoginRunner().loginWithChatGPT(openAuthURL: openAuthURL)
        }.value
    }
}

private final class CodexAppServerLoginRunner {
    private let fileManager = FileManager.default

    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let resolved = resolveCodexAppServerCommand()

        process.executableURL = resolved.executableURL
        process.arguments = resolved.arguments
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            throw CodexKeyringError.codexLoginFailed(reason: error.localizedDescription)
        }

        let writer = input.fileHandleForWriting
        let reader = JSONLineReader(handle: output.fileHandleForReading)

        defer {
            try? writer.close()
            try? output.fileHandleForReading.close()
            if process.isRunning {
                process.terminate()
            }
        }

        try writeJSON([
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "codex-keyring",
                    "title": "Codex Keyring",
                    "version": "1.0"
                ],
                "capabilities": NSNull()
            ]
        ], to: writer)

        _ = try reader.readResponse(matchingID: 1)

        try writeJSON(["method": "initialized"], to: writer)

        try writeJSON([
            "id": 2,
            "method": "account/login/start",
            "params": [
                "type": "chatgpt",
                "codexStreamlinedLogin": true
            ]
        ], to: writer)

        let loginStart = try reader.readResponse(matchingID: 2)
        let login = try parseLoginStart(loginStart)
        try await openAuthURL(login.authURL)
        try reader.waitForLoginCompletion(loginID: login.loginID)
    }

    private func resolveCodexAppServerCommand() -> (executableURL: URL, arguments: [String]) {
        let standalone = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/packages/standalone/current/codex")
        if fileManager.isExecutableFile(atPath: standalone.path) {
            return (standalone, ["app-server", "--listen", "stdio://"])
        }

        return (
            URL(fileURLWithPath: "/usr/bin/env"),
            ["codex", "app-server", "--listen", "stdio://"]
        )
    }

    private func parseLoginStart(_ message: [String: Any]) throws -> (loginID: String, authURL: URL) {
        guard let result = message["result"] as? [String: Any],
              let type = result["type"] as? String else {
            throw CodexKeyringError.codexLoginUnexpectedResponse(reason: "Missing login result.")
        }

        guard type == "chatgpt" else {
            throw CodexKeyringError.codexLoginUnexpectedResponse(reason: "Expected chatgpt login, got \(type).")
        }

        guard let loginID = result["loginId"] as? String,
              let authURLString = result["authUrl"] as? String,
              let authURL = URL(string: authURLString) else {
            throw CodexKeyringError.codexLoginUnexpectedResponse(reason: "Missing auth URL or login ID.")
        }

        return (loginID, authURL)
    }

    private func writeJSON(_ object: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        handle.write(data)
        handle.write(Data([0x0A]))
    }
}

private final class JSONLineReader {
    private let handle: FileHandle
    private var buffer = Data()

    init(handle: FileHandle) {
        self.handle = handle
    }

    func readResponse(matchingID expectedID: Int) throws -> [String: Any] {
        while let message = try readMessage() {
            if let error = message["error"] as? [String: Any] {
                let reason = error["message"] as? String ?? "Unknown app-server error."
                throw CodexKeyringError.codexLoginFailed(reason: reason)
            }

            if matches(message["id"], expectedID) {
                return message
            }
        }

        throw CodexKeyringError.codexLoginFailed(reason: "Codex app-server stopped before responding.")
    }

    func waitForLoginCompletion(loginID: String) throws {
        while let message = try readMessage() {
            guard message["method"] as? String == "account/login/completed",
                  let params = message["params"] as? [String: Any] else {
                continue
            }

            if let completedLoginID = params["loginId"] as? String,
               completedLoginID != loginID {
                continue
            }

            let success = params["success"] as? Bool ?? false
            if success {
                return
            }

            let reason = params["error"] as? String ?? "The browser login did not complete."
            throw CodexKeyringError.codexLoginFailed(reason: reason)
        }

        throw CodexKeyringError.codexLoginFailed(reason: "Codex app-server stopped before login completed.")
    }

    private func readMessage() throws -> [String: Any]? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                guard !line.isEmpty else { continue }

                guard let object = try JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else {
                    throw CodexKeyringError.codexLoginUnexpectedResponse(reason: "Received non-object JSON.")
                }
                return object
            }

            let chunk = handle.readData(ofLength: 4096)
            if chunk.isEmpty {
                return nil
            }
            buffer.append(chunk)
        }
    }

    private func matches(_ rawID: Any?, _ expectedID: Int) -> Bool {
        if let intID = rawID as? Int {
            return intID == expectedID
        }
        if let stringID = rawID as? String {
            return stringID == String(expectedID)
        }
        return false
    }
}

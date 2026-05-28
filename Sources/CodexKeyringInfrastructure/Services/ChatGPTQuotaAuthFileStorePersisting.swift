import Foundation
import CodexKeyringDomain

extension ChatGPTQuotaAuthFileStore {
    static func persistSync(_ auth: StoredChatGPTAuth, to url: URL) throws {
        var object = auth.sourceObject
        var tokens = object["tokens"] as? [String: Any] ?? [:]
        tokens["access_token"] = auth.accessToken
        if let refreshToken = auth.refreshToken {
            tokens["refresh_token"] = refreshToken
        }
        if let idToken = auth.idToken {
            tokens["id_token"] = idToken
        }
        if let accountID = auth.accountID {
            tokens["account_id"] = accountID
        }
        object["tokens"] = tokens
        object["auth_mode"] = "chatgpt"
        object["last_refresh"] = ChatGPTOAuthLoginService.iso8601String(from: Date())

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        let directory = url.deletingLastPathComponent()
        let temp = directory.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try PrivateFilePermissions.createDirectory(at: directory)
            try data.write(to: temp, options: [.atomic])
            try PrivateFilePermissions.setFile(at: temp)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: url)
            }
            try PrivateFilePermissions.setFile(at: url)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not write refreshed auth snapshot: \(error.localizedDescription)"
            )
        }
    }
}

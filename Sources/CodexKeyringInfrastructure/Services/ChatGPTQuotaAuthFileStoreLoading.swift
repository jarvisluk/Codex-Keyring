import Foundation
import CodexKeyringDomain

extension ChatGPTQuotaAuthFileStore {
    static func loadSync(from url: URL) throws -> StoredChatGPTAuth {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CodexKeyringError.authFileMissing(url)
        }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.authFileUnreadable
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CodexKeyringError.authFileUnreadable
        }

        let object = try jsonObject(from: data)
        guard let tokens = object["tokens"] as? [String: Any] else {
            throw CodexKeyringError.unsupportedAuthShape
        }
        let authMode = nonEmpty(object["auth_mode"] as? String) ?? "chatgpt"
        guard authMode == "chatgpt" else {
            throw CodexKeyringError.quotaQueryFailed(reason: "Only ChatGPT OAuth accounts expose Codex quota.")
        }

        let accessToken = nonEmpty(tokens["access_token"] as? String)
        let refreshToken = nonEmpty(tokens["refresh_token"] as? String)
        let idToken = nonEmpty(tokens["id_token"] as? String)
        guard accessToken != nil || refreshToken != nil else {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved auth snapshot has no access or refresh token.")
        }

        let tokenMetadata = TokenMetadata.from(accessToken: accessToken, idToken: idToken)
        let accountID = nonEmpty(tokens["account_id"] as? String)
            ?? tokenMetadata.accountID

        return StoredChatGPTAuth(
            sourceObject: object,
            accessToken: accessToken ?? "",
            refreshToken: refreshToken,
            idToken: idToken,
            accountID: accountID,
            planType: tokenMetadata.planType,
            email: tokenMetadata.email
        )
    }
}

private func jsonObject(from data: Data) throws -> [String: Any] {
    guard let parsed = try? JSONSerialization.jsonObject(with: data),
          let object = parsed as? [String: Any]
    else {
        throw CodexKeyringError.authFileUnreadable
    }
    return object
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    return value
}

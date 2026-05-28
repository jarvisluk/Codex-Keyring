import Foundation
import CodexKeyringDomain

extension ChatGPTQuotaClient {
    func shouldRefreshAccessToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return true }
        guard let expiresAt = TokenMetadata.expiration(from: token) else { return false }
        return expiresAt <= Date().addingTimeInterval(60)
    }

    func refreshAuthAndMetadata(
        _ auth: StoredChatGPTAuth,
        request: AccountQuotaQueryRequest
    ) async throws -> (StoredChatGPTAuth, AuthMetadata?) {
        let refreshed = try await refreshAndPersistAuth(auth, request: request)
        let metadata = try await authReader.read(from: request.snapshotURL)
        return (refreshed, metadata)
    }

    func refreshAndPersistAuth(
        _ auth: StoredChatGPTAuth,
        request: AccountQuotaQueryRequest
    ) async throws -> StoredChatGPTAuth {
        guard let refreshToken = auth.refreshToken, !refreshToken.isEmpty else {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved access token expired and no refresh token is available.")
        }

        let refreshResponse = try await httpClient.refreshTokens(refreshToken: refreshToken)
        let updated = refreshedAuth(from: auth, response: refreshResponse)

        // For the active account, keep the live Codex auth valid first. If the
        // later snapshot write fails, the file watcher can still re-capture it
        // from the now-fresh live auth instead of leaving Codex with a spent
        // refresh token.
        if let liveAuthFileURL = request.liveAuthFileURL {
            try await authStore.persist(updated, to: liveAuthFileURL)
        }
        try await authStore.persist(updated, to: request.snapshotURL)
        return try await authStore.load(from: request.snapshotURL)
    }

    private func refreshedAuth(
        from auth: StoredChatGPTAuth,
        response: RefreshTokenResponse
    ) -> StoredChatGPTAuth {
        var updated = auth
        updated.accessToken = response.accessToken
        updated.refreshToken = response.refreshToken ?? auth.refreshToken
        updated.idToken = response.idToken ?? auth.idToken
        updated.accountID = updated.accountID
            ?? TokenMetadata.from(accessToken: response.accessToken, idToken: response.idToken).accountID
        return updated
    }
}

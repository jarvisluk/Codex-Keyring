import Foundation
import CodexKeyringDomain

extension ChatGPTQuotaClient {
    func queryUsage(
        auth: StoredChatGPTAuth,
        request: AccountQuotaQueryRequest,
        updatedMetadata: AuthMetadata?
    ) async throws -> AccountQuotaQueryResult {
        let payload = try await fetchUsage(accessToken: auth.accessToken, accountID: auth.accountID)
        let fetchedAt = Date()
        let resetCredits = await fetchRateLimitResetCreditsIfNeeded(
            usagePayload: payload,
            accessToken: auth.accessToken,
            accountID: auth.accountID,
            fetchedAt: fetchedAt
        )
        let snapshot = try ChatGPTQuotaSnapshotMapper.makeSnapshot(
            payload: payload,
            account: request.account,
            auth: auth,
            endpoint: httpClient.usageURL.absoluteString,
            resetCredits: resetCredits,
            fetchedAt: fetchedAt
        )
        return AccountQuotaQueryResult(
            state: .available(snapshot),
            updatedMetadata: updatedMetadata
        )
    }

    func fetchUsage(accessToken: String, accountID: String?) async throws -> UsagePayload {
        try await httpClient.fetchUsage(accessToken: accessToken, accountID: accountID)
    }

    func fetchRateLimitResetCreditsIfNeeded(
        usagePayload: UsagePayload,
        accessToken: String,
        accountID: String?,
        fetchedAt: Date
    ) async -> AccountRateLimitResetCredits? {
        guard usagePayload.rateLimitResetCredits?.availableCount ?? 0 > 0 else {
            return nil
        }

        do {
            let payload = try await httpClient.fetchRateLimitResetCredits(
                accessToken: accessToken,
                accountID: accountID
            )
            return ChatGPTRateLimitResetCreditsMapper.makeCredits(
                payload: payload,
                fetchedAt: fetchedAt,
                endpoint: httpClient.rateLimitResetCreditsURL.absoluteString
            )
        } catch {
            return ChatGPTRateLimitResetCreditsMapper.makeSummary(
                payload: usagePayload.rateLimitResetCredits,
                fetchedAt: fetchedAt,
                endpoint: httpClient.usageURL.absoluteString
            )
        }
    }
}

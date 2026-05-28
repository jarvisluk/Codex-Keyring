import CodexKeyringDomain

extension ChatGPTQuotaClient {
    func queryUsage(
        auth: StoredChatGPTAuth,
        request: AccountQuotaQueryRequest,
        updatedMetadata: AuthMetadata?
    ) async throws -> AccountQuotaQueryResult {
        let payload = try await fetchUsage(accessToken: auth.accessToken, accountID: auth.accountID)
        let snapshot = try ChatGPTQuotaSnapshotMapper.makeSnapshot(
            payload: payload,
            account: request.account,
            auth: auth,
            endpoint: httpClient.usageURL.absoluteString
        )
        return AccountQuotaQueryResult(
            state: .available(snapshot),
            updatedMetadata: updatedMetadata
        )
    }

    func fetchUsage(accessToken: String, accountID: String?) async throws -> UsagePayload {
        try await httpClient.fetchUsage(accessToken: accessToken, accountID: accountID)
    }
}

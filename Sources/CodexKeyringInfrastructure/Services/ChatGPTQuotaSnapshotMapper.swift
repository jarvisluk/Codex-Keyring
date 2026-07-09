import Foundation
import CodexKeyringDomain

enum ChatGPTQuotaSnapshotMapper {
    static func makeSnapshot(
        payload: UsagePayload,
        account: CodexAccount,
        auth: StoredChatGPTAuth,
        endpoint: String,
        resetCredits: AccountRateLimitResetCredits? = nil,
        fetchedAt: Date = Date()
    ) throws -> AccountQuotaSnapshot {
        let planType = nonEmpty(payload.planType)
            ?? nonEmpty(payload.rateLimit?.planType)
            ?? auth.planType
            ?? account.plan
        let email = nonEmpty(payload.email) ?? auth.email ?? account.email
        var buckets: [QuotaBucket] = []

        buckets.append(
            ChatGPTQuotaBucketMapper.makePrimaryBucket(
                payload: payload,
                planType: planType,
            )
        )

        for additional in payload.additionalRateLimits ?? [] {
            buckets.append(
                ChatGPTQuotaBucketMapper.makeAdditionalBucket(additional, planType: planType)
            )
        }

        buckets = buckets.filter(ChatGPTQuotaBucketMapper.isDisplayable)
        guard !buckets.isEmpty else {
            throw CodexKeyringError.quotaQueryFailed(reason: "No quota buckets were returned.")
        }

        return AccountQuotaSnapshot(
            accountID: account.id,
            planType: planType,
            email: email,
            fetchedAt: fetchedAt,
            buckets: buckets,
            endpoint: endpoint,
            rateLimitResetCredits: resetCredits ?? ChatGPTRateLimitResetCreditsMapper.makeSummary(
                payload: payload.rateLimitResetCredits,
                fetchedAt: fetchedAt,
                endpoint: endpoint
            )
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}

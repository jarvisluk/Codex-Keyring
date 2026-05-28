import Foundation
import CodexKeyringDomain

enum ChatGPTQuotaBucketMapper {
    static func makePrimaryBucket(payload: UsagePayload, planType: String?) -> QuotaBucket {
        makeBucket(
            limitID: nonEmpty(payload.rateLimit?.limitID) ?? "codex",
            limitName: nonEmpty(payload.rateLimit?.limitName),
            planType: planType,
            rateLimit: payload.rateLimit,
            credits: payload.credits ?? payload.rateLimit?.credits,
            rateLimitReachedType: payload.rateLimitReachedType?.normalizedValue
                ?? payload.rateLimit?.rateLimitReachedType?.normalizedValue
        )
    }

    static func makeAdditionalBucket(
        _ additional: AdditionalRateLimitDTO,
        planType: String?
    ) -> QuotaBucket {
        makeBucket(
            limitID: nonEmpty(additional.meteredFeature),
            limitName: nonEmpty(additional.limitName),
            planType: planType,
            rateLimit: additional.rateLimit,
            credits: nil,
            rateLimitReachedType: nil
        )
    }

    static func isDisplayable(_ bucket: QuotaBucket) -> Bool {
        !bucket.windows.isEmpty
            || bucket.credits != nil
            || bucket.rateLimitReachedType != nil
            || bucket.isUnlimited
    }

    private static func makeBucket(
        limitID: String?,
        limitName: String?,
        planType: String?,
        rateLimit: RateLimitDetails?,
        credits: CreditsDTO?,
        rateLimitReachedType: String?
    ) -> QuotaBucket {
        let windows = [
            rateLimit?.primaryWindow,
            rateLimit?.secondaryWindow
        ].compactMap { $0?.asQuotaWindow }
        let quotaCredits = credits.map {
            QuotaCredits(balance: $0.balance, hasCredits: $0.hasCredits, unlimited: $0.unlimited)
        }
        return QuotaBucket(
            limitID: limitID,
            limitName: limitName,
            planType: planType,
            windows: windows,
            credits: quotaCredits,
            rateLimitReachedType: rateLimitReachedType
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}

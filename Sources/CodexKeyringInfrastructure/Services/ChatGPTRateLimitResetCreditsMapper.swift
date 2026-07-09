import Foundation
import CodexKeyringDomain

enum ChatGPTRateLimitResetCreditsMapper {
    static func makeCredits(
        payload: RateLimitResetCreditsPayload,
        fetchedAt: Date,
        endpoint: String
    ) -> AccountRateLimitResetCredits {
        AccountRateLimitResetCredits(
            availableCount: payload.availableCount,
            credits: payload.credits.enumerated().map { index, credit in
                makeCredit(credit, index: index, fetchedAt: fetchedAt)
            },
            fetchedAt: fetchedAt,
            endpoint: endpoint
        )
    }

    static func makeSummary(
        payload: RateLimitResetCreditsSummaryDTO?,
        fetchedAt: Date,
        endpoint: String
    ) -> AccountRateLimitResetCredits? {
        guard let payload, payload.availableCount > 0 else { return nil }
        return AccountRateLimitResetCredits(
            availableCount: payload.availableCount,
            credits: [],
            fetchedAt: fetchedAt,
            endpoint: endpoint
        )
    }

    private static func makeCredit(
        _ credit: RateLimitResetCreditDTO,
        index: Int,
        fetchedAt: Date
    ) -> RateLimitResetCredit {
        RateLimitResetCredit(
            id: credit.id ?? "reset-credit-\(index + 1)",
            title: credit.title,
            description: credit.description,
            status: credit.status,
            expiresAt: credit.expiresAt ?? relativeExpirationDate(
                expiresInSeconds: credit.expiresInSeconds,
                fetchedAt: fetchedAt
            ),
            profileUserID: credit.profileUserID,
            profileImageURL: credit.profileImageURL
        )
    }

    private static func relativeExpirationDate(
        expiresInSeconds: TimeInterval?,
        fetchedAt: Date
    ) -> Date? {
        guard let expiresInSeconds else { return nil }
        return fetchedAt.addingTimeInterval(expiresInSeconds)
    }
}

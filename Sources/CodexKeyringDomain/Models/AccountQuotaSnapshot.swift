import Foundation

public struct AccountQuotaSnapshot: Codable, Equatable, Sendable {
    public var accountID: UUID
    public var planType: String?
    public var email: String?
    public var fetchedAt: Date
    public var buckets: [QuotaBucket]
    public var endpoint: String?

    public init(
        accountID: UUID,
        planType: String?,
        email: String?,
        fetchedAt: Date,
        buckets: [QuotaBucket],
        endpoint: String?
    ) {
        self.accountID = accountID
        self.planType = planType
        self.email = email
        self.fetchedAt = fetchedAt
        self.buckets = buckets
        self.endpoint = endpoint
    }

    public var primaryBucket: QuotaBucket? {
        buckets.first { bucket in
            QuotaString.normalizedNonEmpty(bucket.limitID)?
                .localizedCaseInsensitiveCompare("codex") == .orderedSame
        } ?? buckets.first
    }

    public var health: QuotaHealth {
        primaryBucket?.health ?? .error
    }
}

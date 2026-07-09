import Foundation

public struct AccountRateLimitResetCredits: Codable, Equatable, Sendable {
    public var availableCount: Int
    public var credits: [RateLimitResetCredit]
    public var fetchedAt: Date
    public var endpoint: String?

    public init(
        availableCount: Int,
        credits: [RateLimitResetCredit],
        fetchedAt: Date,
        endpoint: String?
    ) {
        self.availableCount = max(0, availableCount)
        self.credits = credits
        self.fetchedAt = fetchedAt
        self.endpoint = endpoint
    }

    public var availableCredits: [RateLimitResetCredit] {
        credits.filter(\.isAvailable)
    }

    public var visibleAvailableCount: Int {
        max(availableCount, availableCredits.count)
    }

    public var hasAvailableCredits: Bool {
        visibleAvailableCount > 0
    }

    public var nextExpirationDate: Date? {
        availableCredits.compactMap(\.expiresAt).min()
    }
}

public struct RateLimitResetCredit: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String?
    public var description: String?
    public var status: String?
    public var expiresAt: Date?
    public var profileUserID: String?
    public var profileImageURL: String?

    public init(
        id: String,
        title: String?,
        description: String?,
        status: String?,
        expiresAt: Date?,
        profileUserID: String?,
        profileImageURL: String?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.expiresAt = expiresAt
        self.profileUserID = profileUserID
        self.profileImageURL = profileImageURL
    }

    public var isAvailable: Bool {
        guard let status = QuotaString.normalizedNonEmpty(status) else { return true }
        return status.localizedCaseInsensitiveCompare("available") == .orderedSame
    }
}

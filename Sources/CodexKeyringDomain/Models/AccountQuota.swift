import Foundation

public enum QuotaHealth: String, Codable, Equatable, Sendable {
    case ready
    case watch
    case low
    case blocked
    case error
    case unsupported
}

public enum AccountQuotaPhase: String, Codable, Equatable, Sendable {
    case idle
    case loading
    case available
    case error
    case unsupported
}

public struct QuotaWindow: Codable, Equatable, Sendable {
    public var usedPercent: Double
    public var windowDurationMinutes: Int?
    public var resetsAt: Date?

    public init(
        usedPercent: Double,
        windowDurationMinutes: Int?,
        resetsAt: Date?
    ) {
        self.usedPercent = usedPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }

    public var durationLabel: String {
        guard let minutes = windowDurationMinutes, minutes > 0 else {
            return "Usage limit"
        }
        switch minutes {
        case 5 * 60:
            return "5-hour"
        case 24 * 60:
            return "Daily"
        case 7 * 24 * 60:
            return "Weekly"
        case 30 * 24 * 60:
            return "Monthly"
        case 365 * 24 * 60:
            return "Annual"
        default:
            if minutes < 60 {
                return "\(minutes)-minute"
            }
            if minutes % (24 * 60) == 0 {
                let days = minutes / (24 * 60)
                return "\(days)-day"
            }
            if minutes % 60 == 0 {
                let hours = minutes / 60
                return "\(hours)-hour"
            }
            return "\(minutes)-minute"
        }
    }
}

public struct QuotaCredits: Codable, Equatable, Sendable {
    public var balance: String?
    public var hasCredits: Bool
    public var unlimited: Bool

    public init(balance: String?, hasCredits: Bool, unlimited: Bool) {
        self.balance = balance
        self.hasCredits = hasCredits
        self.unlimited = unlimited
    }

    public var isDepleted: Bool {
        guard hasCredits, !unlimited else { return false }
        guard let balance = balance?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Double(balance)
        else {
            return false
        }
        return value <= 0
    }
}

public struct QuotaBucket: Codable, Equatable, Sendable, Identifiable {
    public var limitID: String?
    public var limitName: String?
    public var planType: String?
    public var windows: [QuotaWindow]
    public var credits: QuotaCredits?
    public var rateLimitReachedType: String?
    public var health: QuotaHealth

    public init(
        limitID: String?,
        limitName: String?,
        planType: String?,
        windows: [QuotaWindow],
        credits: QuotaCredits?,
        rateLimitReachedType: String?,
        health: QuotaHealth? = nil
    ) {
        self.limitID = limitID
        self.limitName = limitName
        self.planType = planType
        self.windows = windows
        self.credits = credits
        self.rateLimitReachedType = rateLimitReachedType
        self.health = health ?? Self.classify(
            windows: windows,
            credits: credits,
            rateLimitReachedType: rateLimitReachedType,
            planType: planType
        )
    }

    public var id: String {
        normalizedNonEmpty(limitID) ?? normalizedNonEmpty(limitName) ?? "codex"
    }

    public var displayName: String {
        normalizedNonEmpty(limitName) ?? normalizedNonEmpty(limitID) ?? "codex"
    }

    public var remainingPercent: Double? {
        let values = windows.map(\.remainingPercent)
        guard let minimum = values.min() else { return nil }
        return minimum
    }

    public var isUnlimited: Bool {
        if credits?.unlimited == true { return true }
        guard windows.isEmpty, normalizedNonEmpty(rateLimitReachedType) == nil else { return false }
        return Self.isUnmeteredPlan(planType)
    }

    public static func classify(
        windows: [QuotaWindow],
        credits: QuotaCredits?,
        rateLimitReachedType: String?,
        planType: String?
    ) -> QuotaHealth {
        if normalizedNonEmpty(rateLimitReachedType) != nil {
            return .blocked
        }
        if credits?.isDepleted == true {
            return .blocked
        }
        if (credits?.unlimited == true || isUnmeteredPlan(planType)) && windows.isEmpty {
            return .ready
        }
        let remainingValues = windows.map(\.remainingPercent)
        guard let bottleneck = remainingValues.min() else {
            return .error
        }
        if bottleneck <= 5 { return .blocked }
        if bottleneck <= 15 { return .low }
        if bottleneck <= 30 { return .watch }
        return .ready
    }

    private static func isUnmeteredPlan(_ planType: String?) -> Bool {
        guard let normalized = normalizedNonEmpty(planType)?.lowercased() else { return false }
        return normalized == "business" || normalized == "enterprise"
    }
}

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
            normalizedNonEmpty(bucket.limitID)?.localizedCaseInsensitiveCompare("codex") == .orderedSame
        } ?? buckets.first
    }

    public var health: QuotaHealth {
        primaryBucket?.health ?? .error
    }
}

private func normalizedNonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty
    else {
        return nil
    }
    return trimmed
}

public struct AccountQuotaState: Equatable, Sendable {
    public var accountID: UUID
    public var phase: AccountQuotaPhase
    public var snapshot: AccountQuotaSnapshot?
    public var message: String?
    public var updatedAt: Date?

    public init(
        accountID: UUID,
        phase: AccountQuotaPhase,
        snapshot: AccountQuotaSnapshot? = nil,
        message: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.accountID = accountID
        self.phase = phase
        self.snapshot = snapshot
        self.message = message
        self.updatedAt = updatedAt
    }

    public var health: QuotaHealth {
        if let snapshot { return snapshot.health }
        switch phase {
        case .unsupported:
            return .unsupported
        case .error:
            return .error
        case .available:
            return .ready
        case .idle, .loading:
            return .unsupported
        }
    }

    public static func loading(accountID: UUID) -> AccountQuotaState {
        AccountQuotaState(accountID: accountID, phase: .loading)
    }

    public static func unsupported(
        accountID: UUID,
        message: String,
        updatedAt: Date
    ) -> AccountQuotaState {
        AccountQuotaState(
            accountID: accountID,
            phase: .unsupported,
            message: message,
            updatedAt: updatedAt
        )
    }

    public static func error(
        accountID: UUID,
        message: String,
        updatedAt: Date
    ) -> AccountQuotaState {
        AccountQuotaState(
            accountID: accountID,
            phase: .error,
            message: message,
            updatedAt: updatedAt
        )
    }

    public static func available(_ snapshot: AccountQuotaSnapshot) -> AccountQuotaState {
        AccountQuotaState(
            accountID: snapshot.accountID,
            phase: .available,
            snapshot: snapshot,
            updatedAt: snapshot.fetchedAt
        )
    }
}

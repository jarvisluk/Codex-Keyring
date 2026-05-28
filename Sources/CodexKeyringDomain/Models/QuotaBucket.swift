import Foundation

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
        self.health = health ?? QuotaBucketHealthClassifier.classify(
            windows: windows,
            credits: credits,
            rateLimitReachedType: rateLimitReachedType,
            planType: planType
        )
    }

    public var id: String {
        QuotaString.normalizedNonEmpty(limitID)
            ?? QuotaString.normalizedNonEmpty(limitName)
            ?? "codex"
    }

    public var displayName: String {
        QuotaString.normalizedNonEmpty(limitName)
            ?? QuotaString.normalizedNonEmpty(limitID)
            ?? "codex"
    }

    public var remainingPercent: Double? {
        let values = windows.map(\.remainingPercent)
        guard let minimum = values.min() else { return nil }
        return minimum
    }

    public var isUnlimited: Bool {
        if credits?.unlimited == true { return true }
        guard windows.isEmpty,
              QuotaString.normalizedNonEmpty(rateLimitReachedType) == nil
        else {
            return false
        }
        return QuotaBucketHealthClassifier.isUnmeteredPlan(planType)
    }
}

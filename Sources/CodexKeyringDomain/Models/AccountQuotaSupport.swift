import Foundation

enum QuotaString {
    static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}

enum QuotaWindowDurationLabel {
    static func label(minutes: Int?) -> String {
        guard let minutes, minutes > 0 else {
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

enum QuotaBucketHealthClassifier {
    static func classify(
        windows: [QuotaWindow],
        credits: QuotaCredits?,
        rateLimitReachedType: String?,
        planType: String?
    ) -> QuotaHealth {
        if QuotaString.normalizedNonEmpty(rateLimitReachedType) != nil {
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

    static func isUnmeteredPlan(_ planType: String?) -> Bool {
        guard let normalized = QuotaString.normalizedNonEmpty(planType)?.lowercased() else { return false }
        return normalized == "business" || normalized == "enterprise"
    }
}
